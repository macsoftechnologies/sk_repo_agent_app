// lib/screens/verified_cars_screen.dart
import 'dart:async';
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
import '../../models/verified_car.dart';

class VerifiedCarsScreen extends StatefulWidget {
  const VerifiedCarsScreen({Key? key}) : super(key: key);

  @override
  _VerifiedCarsScreenState createState() => _VerifiedCarsScreenState();
}

class _VerifiedCarsScreenState extends State<VerifiedCarsScreen> {
  final TextEditingController searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String userName = "";
  String deviceId = "";
  String userId = "";

  List<VerifiedCar> _cars = [];

  // Pagination & state
  int _page = 1;
  int _perPage = 20;
  int _totalPages = 1;
  int _totalCars = 0;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isRefreshing = false;
  bool _hasError = false;
  String _errorMessage = '';

  // Platform detection
  bool get _isDesktop => kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  void initState() {
    super.initState();
    loadUserData();
    _fetchCars(reset: true);

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMore &&
          !_isLoading &&
          _page < _totalPages) {
        _fetchMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    searchController.dispose();
    super.dispose();
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

  Future<void> _fetchCars({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = '';
        _page = 1;
        _cars = [];
      });
    }

    final regNo = searchController.text.trim();
    final internet = await UtilClass.checkInternet();

    if (!internet) {
      setState(() {
        _hasError = true;
        _errorMessage = Config.kNoInternet;
        _isLoading = false;
      });
      _showPlatformAlertDialog(context: context, message: Config.kNoInternet);
      return;
    }

    final Map<String, dynamic> body = {
      'reg_no': regNo,
      'page': _page,
      'device_token': deviceId.toString(),
      'admin_id': userId.toString(),
    };

    print("🔵 Request Body (verifiedCarsApi): $body");

    try {
      final response = await Repository.postApiRawService(
        EndPoints.verifiedCarsApi,
        body,
      );

      if (response == null) {
        throw Exception('Empty response from server');
      }

      if (response['status'] == true) {
        print("response :veri${response}");
        final data = response['data'] ?? {};
        final carsJson = data['cars'];
        final List<VerifiedCar> fetched = VerifiedCar.listFromJson(carsJson);

        setState(() {
          if (reset) {
            _cars = fetched;
          } else {
            _cars.addAll(fetched);
          }

          _page = (data['page'] is int) ? data['page'] : int.tryParse("${data['page']}") ?? _page;
          _perPage = (data['per_page'] is int) ? data['per_page'] : int.tryParse("${data['per_page']}") ?? _perPage;
          _totalCars = (data['total_cars'] is int) ? data['total_cars'] : int.tryParse("${data['total_cars']}") ?? _totalCars;
          _totalPages = (data['total_pages'] is int) ? data['total_pages'] : int.tryParse("${data['total_pages']}") ?? _totalPages;

          _hasError = false;
          _errorMessage = '';
        });
      } else {
        final msg = response['message']?.toString() ?? 'Failed to fetch cars';
        setState(() {
          _hasError = true;
          _errorMessage = msg;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _isLoadingMore = false;
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

  Future<void> _fetchMore() async {
    if (_page >= _totalPages) return;

    setState(() {
      _isLoadingMore = true;
      _page = _page + 1;
    });

    await _fetchCars(reset: false);
  }

  Future<void> _onRefresh() async {
    setState(() {
      _isRefreshing = true;
      _page = 1;
    });
    await _fetchCars(reset: true);
  }

  void _onSearchPressed() {
    FocusScope.of(context).unfocus();
    _page = 1;
    _fetchCars(reset: true);
  }

  void _onReset() {
    searchController.clear();
    FocusScope.of(context).unfocus();
    _page = 1;
    _fetchCars(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final isDesktop = _isDesktop;

    // Platform-specific dimensions
    final double horizontalPadding = isDesktop ? width * 0.05 : width * 0.04;
    final double verticalSpacing = isDesktop ? height * 0.02 : height * 0.02;
    final double cardSpacing = isDesktop ? height * 0.02 : height * 0.018;
    final double buttonHorizontalPadding = isDesktop ? width * 0.025 : width * 0.035;
    final double buttonVerticalPadding = isDesktop ? height * 0.014 : height * 0.018;

    // Font sizes
    final double titleFontSize = isDesktop ? 16.0 : width * 0.045;
    final double bodyFontSize = isDesktop ? 14.0 : width * 0.036;
    final double smallFontSize = isDesktop ? 12.0 : width * 0.033;
    final double statusFontSize = isDesktop ? 13.0 : width * 0.033;

    return Scaffold(
      backgroundColor: const Color(0xFFeef1f7),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          CustomAppHeader(
            title: "${"verified_cars_title".tr()}",
            onBack: () => Navigator.of(context).pop(),
          ),

          SizedBox(height: verticalSpacing),

          // Main content
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                children: [
                  // Search Section - Platform specific
                  if (isDesktop)
                    _buildDesktopSearchSection(width, height, bodyFontSize)
                  else
                    _buildMobileSearchSection(width, height, buttonHorizontalPadding, buttonVerticalPadding, bodyFontSize),

                  SizedBox(height: verticalSpacing * 0.8),

                  // Summary Stats Bar - Desktop only
                  if (isDesktop)
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _isLoading ? Colors.orange.withOpacity(0.1) :
                                  _hasError ? Colors.red.withOpacity(0.1) :
                                  Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _isLoading ? Colors.orange :
                                    _hasError ? Colors.red :
                                    Colors.green,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _isLoading ? Icons.refresh :
                                      _hasError ? Icons.error_outline :
                                      Icons.check_circle,
                                      size: 14,
                                      color: _isLoading ? Colors.orange :
                                      _hasError ? Colors.red :
                                      Colors.green,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      _isLoading ? 'Loading' :
                                      _hasError ? 'Error' :
                                      'Ready',
                                      style: TextStyle(
                                        fontSize: smallFontSize,
                                        fontWeight: FontWeight.w500,
                                        color: _isLoading ? Colors.orange :
                                        _hasError ? Colors.red :
                                        Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 16),
                              Row(
                                children: [
                                  Icon(Icons.car_rental, size: 16, color: Colors.blue[600]),
                                  SizedBox(width: 6),
                                  Text(
                                    "Total Cars: $_totalCars",
                                    style: TextStyle(
                                      fontSize: smallFontSize,
                                      color: const Color(0xFF666666),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(Icons.filter_list, size: 16, color: Colors.blue[600]),
                              SizedBox(width: 6),
                              Text(
                                "Page $_page of $_totalPages",
                                style: TextStyle(
                                  fontSize: smallFontSize,
                                  color: const Color(0xFF666666),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  SizedBox(height: verticalSpacing),

                  // Content list area
                  Expanded(
                    child: _isLoading && _cars.isEmpty
                        ? _buildInitialLoading(width, height, titleFontSize, smallFontSize)
                        : _hasError && _cars.isEmpty
                        ? _buildErrorUI(width, height, titleFontSize, bodyFontSize, isDesktop)
                        : RefreshIndicator(
                      onRefresh: _onRefresh,
                      child: _cars.isEmpty
                          ? _buildNoData(width, height, titleFontSize, bodyFontSize, isDesktop)
                          : ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.only(bottom: isDesktop ? 40 : 80),
                        itemCount: _cars.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index < _cars.length) {
                            final car = _cars[index];
                            return isDesktop
                                ? _buildDesktopCarCard(car, width, height, bodyFontSize, statusFontSize, cardSpacing)
                                : _buildMobileCarCard(car, width, height, bodyFontSize, statusFontSize, cardSpacing);
                          } else {
                            // loading more indicator
                            return Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: SizedBox(
                                  height: isDesktop ? 28 : 24,
                                  width: isDesktop ? 28 : 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: isDesktop ? 2.5 : 2,
                                    color: MyColors.appThemeDark,
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                      ),
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

  // Desktop Search Section
  Widget _buildDesktopSearchSection(double width, double height, double fontSize) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "🔍 Search Verified Cars",
            style: TextStyle(
              fontSize: fontSize * 1.1,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF444444),
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: '${"search".tr()} with registration number',
                      filled: true,
                      fillColor: Colors.white,
                      hintStyle: TextStyle(color: Colors.grey, fontSize: fontSize),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey[600]),
                    ),
                    style: TextStyle(fontSize: fontSize),
                  ),
                ),
              ),
              SizedBox(width: 12),
              // Search Button with hover
              MouseRegion(
                cursor: _isLoading ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
                child: Container(
                  decoration: BoxDecoration(
                    color: _isLoading ? Colors.blue[300] : const Color(0xFF1572D3),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: _isLoading ? null : [
                      BoxShadow(
                        color: const Color(0xFF1572D3).withOpacity(0.3),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isLoading ? null : _onSearchPressed,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        child: Row(
                          children: [
                            Icon(Icons.search, size: 18, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              '${"search".tr()}',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: fontSize,
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
                cursor: _isLoading ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
                child: Container(
                  decoration: BoxDecoration(
                    color: _isLoading ? Colors.grey[400] : const Color(0xFF555555),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: _isLoading ? null : [
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
                      onTap: _isLoading ? null : _onReset,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        child: Row(
                          children: [
                            Icon(Icons.refresh, size: 18, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              '${"reset".tr()}',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: fontSize,
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
        ],
      ),
    );
  }

  // Mobile Search Section (original)
  Widget _buildMobileSearchSection(double width, double height, double buttonHorizontalPadding, double buttonVerticalPadding, double fontSize) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: '${"search".tr()} with reg no',
              filled: true,
              fillColor: Colors.white,
              hintStyle: const TextStyle(color: Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: width * 0.03,
                vertical: buttonVerticalPadding,
              ),
            ),
          ),
        ),
        SizedBox(width: width * 0.02),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1572D3),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isLoading ? null : _onSearchPressed,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: EdgeInsets.all(buttonHorizontalPadding),
                child: Text(
                  '${"search".tr()}',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: fontSize,
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: width * 0.02),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF555555),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isLoading ? null : _onReset,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: EdgeInsets.all(buttonHorizontalPadding),
                child: Text(
                  '${"reset".tr()}',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: fontSize,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Desktop Car Card
  Widget _buildDesktopCarCard(VerifiedCar car, double width, double height, double fontSize, double statusFontSize, double spacing) {
    final statusColor = car.status.toLowerCase().contains('got sticker')
        ? MyColors.redColorLight
        : const Color(0xFF2aa94f);

    return Container(
      margin: EdgeInsets.only(bottom: spacing),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          width: 6,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF1A2F5C),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        title: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.confirmation_number, size: 16, color: Colors.blue[600]),
                    SizedBox(width: 8),
                    Text(
                      car.regNo,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF333333),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.format_list_numbered, size: 14, color: Colors.grey[600]),
                    SizedBox(width: 8),
                    Text(
                      "S.No: ${car.sNo} | Batch: ${car.batchNumber}",
                      style: TextStyle(
                        fontSize: fontSize * 0.85,
                        color: const Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Spacer(),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withOpacity(0.2),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    car.status.toLowerCase().contains('got sticker') ? Icons.warning : Icons.verified,
                    size: 14,
                    color: Colors.white,
                  ),
                  SizedBox(width: 8),
                  Text(
                    car.status,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: statusFontSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        children: [
          Divider(height: 1, color: Colors.grey[200]),
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDesktopDetailRow("GPS Location:", car.gpsLocation, fontSize),
                SizedBox(height: 12),
                _buildDesktopDetailRow("Location Details:", car.locationDetails, fontSize),
                SizedBox(height: 12),
                _buildDesktopDetailRow("Last Updated:", car.updatedAt, fontSize),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopDetailRow(String label, String value, double fontSize) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: const Color(0xFF666666),
              fontSize: fontSize * 0.9,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: fontSize * 0.9,
              color: const Color(0xFF333333),
            ),
          ),
        ),
      ],
    );
  }

  // Mobile Car Card (original)
  Widget _buildMobileCarCard(VerifiedCar car, double width, double height, double fontSize, double statusFontSize, double spacing) {
    final statusColor = car.status.toLowerCase().contains('got sticker')
        ? MyColors.redColorLight
        : const Color(0xFF2aa94f);

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: spacing),
      padding: EdgeInsets.all(width * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6)],
        border: Border(left: BorderSide(color: const Color(0xFF1A2F5C), width: width * 0.015)),
      ),
      child: Column(
        children: [
          _buildCardRow('${"s_no".tr()}', car.sNo.toString(), width, fontSize),
          _buildCardRow('${"batch_no".tr()}', car.batchNumber, width, fontSize),
          _buildCardRow('${"registration_no".tr()}', car.regNo, width, fontSize),
          Row(
            children: [
              SizedBox(width: width * 0.35, child: Text('${"status".tr()}', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700))),
              Container(
                padding: EdgeInsets.symmetric(horizontal: width * 0.03, vertical: height * 0.005),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: statusColor),
                child: Text(car.status, style: TextStyle(color: Colors.white, fontSize: statusFontSize, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          SizedBox(height: height * 0.008),
          _buildCardRow('${"gps_location".tr()}', car.gpsLocation, width, fontSize),
          _buildCardRow('${"location_details".tr()}', car.locationDetails, width, fontSize),
          _buildCardRow('${"updated_at".tr()}', car.updatedAt, width, fontSize),
        ],
      ),
    );
  }

  Widget _buildCardRow(String label, String value, double width, double fontSize) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: width * 0.35,
            child: Text(label, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: const Color(0xFF333333))),
          ),
          Expanded(child: Text(value, style: TextStyle(fontSize: fontSize, color: Colors.black87))),
        ],
      ),
    );
  }

  // Loading State
  Widget _buildInitialLoading(double width, double height, double titleFontSize, double smallFontSize) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: MyColors.appThemeDark,
            strokeWidth: _isDesktop ? 3 : 2,
          ),
          SizedBox(height: height * 0.02),
          Text(
            "Loading verified cars...",
            style: TextStyle(
              fontSize: titleFontSize,
              color: const Color(0xFF444444),
            ),
          ),
          SizedBox(height: height * 0.01),
          Text(
            "Page $_page of $_totalPages",
            style: TextStyle(
              fontSize: smallFontSize,
              color: const Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }

  // Error State
  Widget _buildErrorUI(double width, double height, double titleFontSize, double fontSize, bool isDesktop) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: height * 0.12),
        Center(
          child: Column(
            children: [
              Icon(
                  Icons.error_outline,
                  size: isDesktop ? 80 : width * 0.18,
                  color: Colors.redAccent
              ),
              SizedBox(height: 10),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: width * 0.06),
                child: Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: titleFontSize, color: Colors.black54),
                ),
              ),
              SizedBox(height: 12),
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
                      onTap: () {
                        _page = 1;
                        _fetchCars(reset: true);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 32 : width * 0.08,
                          vertical: isDesktop ? 14 : height * 0.015,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Retry',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: fontSize,
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
    );
  }

  // No Data View
  Widget _buildNoData(double width, double height, double titleFontSize, double fontSize, bool isDesktop) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: height * 0.15),
        Center(
          child: Column(
            children: [
              Icon(
                  Icons.car_rental,
                  size: isDesktop ? 100 : width * 0.25,
                  color: Colors.grey[300]
              ),
              SizedBox(height: 10),
              Text(
                'No verified cars found',
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF444444),
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Try a different search or check back later',
                style: TextStyle(
                  fontSize: fontSize * 0.9,
                  color: const Color(0xFF666666),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}