import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../components/custom_app_header.dart';
import 'package:repo_agent_application/utils/my_colors.dart';
import '../../data/prefernces.dart';
import '../../services/end_points.dart';
import '../../services/repository.dart';
import '../../utils/config.dart';
import '../../utils/util_class.dart';

class MatchedCarsScreen extends StatefulWidget {
  const MatchedCarsScreen({super.key});

  @override
  State<MatchedCarsScreen> createState() => _MatchedCarsScreenState();
}

class _MatchedCarsScreenState extends State<MatchedCarsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String userName = "";
  String deviceId = "";
  String userId = "";

  // Pagination variables
  List<dynamic> _data = [];
  List<dynamic> _batches = [];
  int _currentPage = 1;
  int _totalPages = 0;
  int _totalCount = 0;
  int _totalSearched = 0;
  bool _isLoading = false;
  bool _hasError = false;
  bool _hasMore = true;
  String _errorMessage = '';

  // Platform detection
  bool get _isDesktop => kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  List<dynamic> get _filteredData {
    if (_searchController.text.isEmpty) return _data;
    final query = _searchController.text.toLowerCase();
    return _data.where((item) {
      final regNo = item['reg_no']?.toString().toLowerCase() ?? '';
      return regNo.contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    loadUserData();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMoreData();
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


  void _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _currentPage = 1;
      _data = [];
      _batches = [];
    });
    print("in _loadInitialData");

    await _fetchData(page: 1, isInitial: true);
  }

  void _loadMoreData() {
    if (!_isLoading && _hasMore && _currentPage < _totalPages) {
      _fetchData(page: _currentPage + 1);
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

  Future<void> _fetchData({required int page, bool isInitial = false}) async {
    print("in _fetchData1");
    print("in _fetchData2");

    setState(() {
      _isLoading = true;
      if (isInitial) {
        _hasError = false;
      }
    });

    final internet = await UtilClass.checkInternet();

    if (!internet) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = Config.kNoInternet;
      });
      if (isInitial) {
        _showPlatformAlertDialog(context: context, message: Config.kNoInternet);
      }
      return;
    }
    print("in _fetchData3");

    try {
      print("Fetching matched cars page $page with device: $deviceId");

      final value = await Repository.postApiRawService(
          EndPoints.matchedCarsApi,
          {
            'device_token': deviceId.toString(),
            'admin_id': userId.toString(),
            "page": page,
          }
      );

      UtilClass.hideProgress();
      print("🔵 API Response for page $page: ${value.toString()}");

      // Handle different response formats
      dynamic parsed;
      if (value is String) {
        parsed = json.decode(value);
      } else {
        parsed = value;
      }

      print("🟢 Parsed response type: ${parsed.runtimeType}");
      print("🟢 Success status: ${parsed["success"]}");
      print("🟢 Matched cars data type: ${parsed["matched_cars"]?.runtimeType}");
      print("🟢 Matched cars length: ${parsed["matched_cars"] is List ? parsed["matched_cars"].length : 'N/A'}");
      print("🟢 Batches length: ${parsed["batches"] is List ? parsed["batches"].length : 'N/A'}");

      if (parsed["success"] == true) {
        final newData = parsed["matched_cars"] ?? [];
        final batches = parsed["batches"] ?? [];
        final totalPages = parsed["total_pages"] ?? 1;
        final totalSearched = parsed["total_searched"] ?? 0;

        print("✅ Page $page: Received ${newData.length} matched cars, Total pages: $totalPages, Total searched: $totalSearched");

        setState(() {
          if (page == 1) {
            _data = List.from(newData);
            _batches = List.from(batches);
          } else {
            _data.addAll(newData);
          }
          _currentPage = page;
          _totalPages = totalPages;
          _totalSearched = int.tryParse(totalSearched.toString()) ?? 0;
          _totalCount = _data.length;
          _hasMore = page < totalPages;
          _isLoading = false;
          _hasError = false;
        });

        print("✅ Updated state: ${_data.length} total matched cars, Has more: $_hasMore");
      } else {
        final errorMsg = parsed["message"] ?? "Failed to load matched cars";
        print("❌ API returned error: $errorMsg");
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = errorMsg;
        });
      }
    } catch (e, stackTrace) {
      UtilClass.hideProgress();
      print("❌ API Error: $e");
      print("❌ Stack trace: $stackTrace");
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = "Connection error: ${e.toString()}";
      });
      if (isInitial) {
        _showPlatformAlertDialog(context: context, message: e.toString());
      }
    }
  }

  void _resetSearch() {
    setState(() {
      _searchController.clear();
    });
  }

  void _retryAPI() {
    _loadInitialData();
  }

  void _refreshData() {
    _loadInitialData();
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: EdgeInsets.all(16.0),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(
              color: MyColors.appThemeDark,
            ),
            SizedBox(height: 10),
            Text(
              "Loading more cars...",
              style: TextStyle(
                fontSize: 14,
                color: const Color(0xFF444444),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndOfList() {
    return Padding(
      padding: EdgeInsets.all(16.0),
      child: Center(
        child: Text(
          _data.isEmpty ? "No cars available" : "All cars loaded",
          style: TextStyle(
            fontSize: 14,
            color: const Color(0xFF666666),
          ),
        ),
      ),
    );
  }

  // Helper function to format date
  String _formatDate(String dateString) {
    try {
      final dateTime = DateTime.parse(dateString);
      return "${dateTime.day}/${dateTime.month}/${dateTime.year}";
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

  // Helper function to get status color
  Color _getStatusColorForCar(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
        return Colors.green;
      case 'unverified':
        return MyColors.appThemeDark;
      default:
        return Colors.grey;
    }
  }


  void _handleMatchedCars() {
    print("yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy");
    Navigator.pushNamed(
      context,
      Config.matchedCarDetailsRouteName,
      arguments: {
        'regNo': 'TODAYCAR11',   // your dynamic value
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final isDesktop = _isDesktop;

    // Platform-specific dimensions
    final double horizontalPadding = isDesktop ? width * 0.05 : width * 0.04;
    final double verticalSpacing = isDesktop ? height * 0.02 : height * 0.01;
    final double cardSpacing = isDesktop ? height * 0.02 : height * 0.0075;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F4FF),
      body: Column(
        children: [
          CustomAppHeader(
            title:'${"matched_cars_title".tr()}',
            onBack: () {
              Navigator.pop(context);
            },
          ),

          // Desktop-specific summary bar
          if (isDesktop && _data.isNotEmpty && !_isLoading)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: horizontalPadding),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blue[100]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, size: 14, color: Colors.blue[600]),
                            SizedBox(width: 6),
                            Text(
                              "Total Searched: $_totalSearched",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green[100]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.car_rental, size: 14, color: Colors.green[600]),
                            SizedBox(width: 6),
                            Text(
                              "Matched: ${_data.length}",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Text(
                          "Page $_currentPage of $_totalPages",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Mobile-specific stats (original)
          if (!isDesktop && _data.isNotEmpty && !_isLoading)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: width * 0.04, vertical: height * 0.01),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Total: $_totalSearched searched",
                    style: TextStyle(
                      fontSize: width * 0.032,
                      color: const Color(0xFF666666),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    "Page $_currentPage of $_totalPages",
                    style: TextStyle(
                      fontSize: width * 0.032,
                      color: const Color(0xFF666666),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    "Loaded: ${_data.length} cars",
                    style: TextStyle(
                      fontSize: width * 0.032,
                      color: const Color(0xFF666666),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          SizedBox(height: verticalSpacing),

          // Loading Indicator for initial load
          if (_isLoading && _data.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: MyColors.appThemeDark,
                      strokeWidth: isDesktop ? 3 : 2,
                    ),
                    SizedBox(height: height * 0.02),
                    Text(
                      "Loading matched cars...",
                      style: TextStyle(
                        fontSize: isDesktop ? 16 : width * 0.04,
                        color: const Color(0xFF444444),
                      ),
                    ),
                    SizedBox(height: height * 0.01),
                    Text(
                      "Page $_currentPage of $_totalPages",
                      style: TextStyle(
                        fontSize: isDesktop ? 14 : width * 0.03,
                        color: const Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
            )
          // Error State
          else if (_hasError && _data.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: isDesktop ? 80 : width * 0.25,
                      color: Colors.red[400],
                    ),
                    SizedBox(height: height * 0.02),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 80 : width * 0.1),
                      child: Text(
                        _errorMessage,
                        style: TextStyle(
                          fontSize: isDesktop ? 16 : width * 0.04,
                          color: const Color(0xFF444444),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(height: height * 0.02),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        decoration: BoxDecoration(
                          color: MyColors.appThemeDark,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: isDesktop ? [
                            BoxShadow(
                              color: MyColors.appThemeDark.withOpacity(0.3),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ] : null,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _retryAPI,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isDesktop ? 32 : width * 0.06,
                                vertical: isDesktop ? 14 : height * 0.015,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.refresh, color: Colors.white, size: isDesktop ? 18 : 16),
                                  SizedBox(width: 8),
                                  Text(
                                    "Retry",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: isDesktop ? 14 : width * 0.035,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          // Main Content
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  _refreshData();
                },
                child: isDesktop
                    ? _buildDesktopContent(width, height, horizontalPadding, cardSpacing)
                    : _buildMobileContent(width, height, horizontalPadding, cardSpacing),
              ),
            ),
        ],
      ),
    );
  }

  // =========================== DESKTOP UI ===========================

  Widget _buildDesktopContent(double width, double height, double horizontalPadding, double cardSpacing) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(horizontalPadding),
            child: Column(
              children: [
                // Desktop Header Summary
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: MyColors.appThemeDark,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: MyColors.appThemeDark.withOpacity(0.3),
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "🚗 ${"matched_cars_title".tr()}",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: MyColors.redColorLight,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 6,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              "Matched: ${_data.length}",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text(
                        "Found ${_data.length} matching vehicles out of $_totalSearched total searches",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      SizedBox(height: 20),

                      // Desktop Search Row
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.white,
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                    hintText: "Search by registration number...",
                                    hintStyle: TextStyle(color: Colors.grey[600]),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            // Search Button with hover
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0a8dff),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF0a8dff).withOpacity(0.3),
                                      blurRadius: 6,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      FocusScope.of(context).unfocus();
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                      child: Row(
                                        children: [
                                          Icon(Icons.search, size: 18, color: Colors.white),
                                          SizedBox(width: 8),
                                          Text(
                                            "${"search".tr()}",
                                            style: TextStyle(
                                              color: Colors.white,
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
                            SizedBox(width: 8),
                            // Reset Button with hover
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[600],
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _resetSearch,
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                      child: Row(
                                        children: [
                                          Icon(Icons.refresh, size: 18, color: Colors.white),
                                          SizedBox(width: 8),
                                          Text(
                                            "${"reset".tr()}",
                                            style: TextStyle(
                                              color: Colors.white,
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
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // Cars List
        if (_filteredData.isNotEmpty)
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.5,
              ),
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  return _buildDesktopCarCard(_filteredData[index], width, height);
                },
                childCount: _filteredData.length,
              ),
            ),
          )
        else if (!_isLoading)
          SliverToBoxAdapter(
            child: _buildDesktopNoCarsView(width, height, horizontalPadding),
          ),

        // Loading more indicator
        if (_isLoading && _data.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      color: MyColors.appThemeDark,
                    ),
                    SizedBox(height: 16),
                    Text(
                      "Loading more cars...",
                      style: TextStyle(
                        fontSize: 14,
                        color: const Color(0xFF444444),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // End of list indicator
        if (!_hasMore && _data.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  "All ${_data.length} cars loaded",
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF666666),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDesktopCarCard(dynamic item, double width, double height) {
    final regNo = item['reg_no']?.toString() ?? 'N/A';
    final carMake = item['car_make']?.toString() ?? 'No model information';
    final status = item['status']?.toString() ?? 'Unverified';
    final searchCount = item['search_count']?.toString() ?? '0';
    final createdAt = item['created_at']?.toString() ?? '';
    final formattedDate = _formatDate(createdAt);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.pushNamed(
                context,
                Config.matchedCarDetailsRouteName,
                arguments: {
                  'regNo': regNo,
                },
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  // Left side - Car icon and basic info
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: MyColors.cardBackColor5.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:MyColors.appThemeDark1.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.car_rental,
                        size: 30,
                        color: _getStatusColorForCar(status),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),

                  // Middle - Car details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          regNo,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF333333),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          carMake,
                          style: TextStyle(
                            fontSize: 14,
                            color: const Color(0xFF666666),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                            SizedBox(width: 6),
                            Text(
                              formattedDate,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Right side - Status and actions
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[100]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, size: 12, color: Colors.blue[600]),
                            SizedBox(width: 4),
                            Text(
                              "$searchCount searches",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[600],
                                fontWeight: FontWeight.w500,
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
        ),
      ),
    );
  }

  Widget _buildDesktopNoCarsView(double width, double height, double horizontalPadding) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(horizontalPadding),
      padding: EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.car_repair,
            size: 80,
            color: Colors.grey[300],
          ),
          SizedBox(height: 20),
          Text(
            _data.isEmpty ? "🚫 No Matched Cars Found" : "🚫 No Matching Results",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF333333),
            ),
          ),
          SizedBox(height: 12),

          Text(
            _data.isEmpty
                ? "There are currently no matched cars in the system."
                : "No cars match your search criteria.",
            textAlign: TextAlign.center, // Correct placement
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 20),
          SizedBox(height: 20),
          if (_hasError)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                decoration: BoxDecoration(
                  color: MyColors.appThemeDark,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: MyColors.appThemeDark.withOpacity(0.3),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _retryAPI,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            "Try Again",
                            style: TextStyle(
                              color: Colors.white,
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
        ],
      ),
    );
  }

  // =========================== MOBILE UI (ORIGINAL) ===========================

  Widget _buildMobileContent(double width, double height, double horizontalPadding, double cardSpacing) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // Header Summary Section
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(horizontalPadding),
            child: Column(
              children: [
                // -------- Header summary section ----------
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(width * 0.05),
                  decoration: BoxDecoration(
                    color: MyColors.appThemeDark,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${"matched_cars_title".tr()}",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: height * 0.01),
                      Text(
                        "Matched ${_data.length} out of $_totalSearched searched cars",
                        style: TextStyle(
                          fontSize: width * 0.04,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: height * 0.01),
                      Center(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: height * 0.008,
                            horizontal: width * 0.04,
                          ),
                          decoration: BoxDecoration(
                            color: MyColors.redColorLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "${"total".tr()}: ${_data.length}",
                            style: TextStyle(
                              fontSize: width * 0.05,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),

                SizedBox(height: height * 0.02),

                // -------- Search Row ----------
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: "Search by reg no ",
                          hintStyle: TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.all(width * 0.03),
                          fillColor: Colors.white,
                          filled: true,
                        ),
                      ),
                    ),
                    SizedBox(width: width * 0.03),
                    Container(
                      padding: EdgeInsets.all(width * 0.03),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0a8dff),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text("${"search".tr()}", style: TextStyle(color: Colors.white)),
                    ),
                    SizedBox(width: width * 0.02),
                    GestureDetector(
                      onTap: _resetSearch,
                      child: Container(
                        padding: EdgeInsets.all(width * 0.03),
                        decoration: BoxDecoration(
                          color: Colors.grey,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text("${"reset".tr()}", style: TextStyle(color: Colors.white)),
                      ),
                    )
                  ],
                ),

                SizedBox(height: height * 0.015),
              ],
            ),
          ),
        ),

        // Cars List
        if (_filteredData.isNotEmpty)
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                return _buildMobileCarCard(_filteredData[index], width, height);
              },
              childCount: _filteredData.length,
            ),
          )
        else if (!_isLoading)
          SliverToBoxAdapter(
            child: _buildMobileNoCarsView(width, height),
          ),

        // Loading more indicator
        if (_isLoading && _data.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildLoadingIndicator(),
          ),

        // End of list indicator
        if (!_hasMore && _data.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildEndOfList(),
          ),
      ],
    );
  }

  Widget _buildMobileCarCard(dynamic item, double width, double height) {
    final regNo = item['reg_no']?.toString() ?? 'N/A';
    final carMake = item['car_make']?.toString() ?? 'No model information';
    final status = item['status']?.toString() ?? 'Unverified';
    final searchCount = item['search_count']?.toString() ?? '0';
    final createdAt = item['created_at']?.toString() ?? '';
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
        margin: EdgeInsets.symmetric(horizontal: width * 0.04, vertical: height * 0.0075),
        padding: EdgeInsets.all(width * 0.04),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 3),
          ],
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
                      vertical: height * 0.004, horizontal: width * 0.03),
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
              style: TextStyle(
                fontSize: width * 0.038,
                color: Colors.black54,
              ),
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
                  style: TextStyle(
                    fontSize: width * 0.04,
                    color: Colors.blue,
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMobileNoCarsView(double width, double height) {
    return Center(
      child: Container(
        padding: EdgeInsets.all(width * 0.05),
        margin: EdgeInsets.all(width * 0.04),
        decoration: BoxDecoration(
          color: Color(0xFFFFE6E6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          _data.isEmpty ? "🚫 No matched cars found!" : "🚫 No matching results!",
          style: TextStyle(
            fontSize: width * 0.04,
            fontWeight: FontWeight.bold,
            color: Color(0xFFD60000),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}