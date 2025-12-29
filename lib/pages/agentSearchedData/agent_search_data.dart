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

class AgentSearchDataScreen extends StatefulWidget {
  const AgentSearchDataScreen({Key? key}) : super(key: key);

  @override
  State<AgentSearchDataScreen> createState() => _AgentSearchDataScreenState();
}

class _AgentSearchDataScreenState extends State<AgentSearchDataScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();

  String userName = "";
  String deviceId = "";
  String userId = "";

  // Pagination variables
  List<dynamic> _data = [];
  int _currentPage = 1;
  int _totalPages = 0;
  int _totalCount = 0;
  bool _isLoading = false;
  bool _hasError = false;
  bool _hasMore = true;
  String _errorMessage = '';

  // Selection variables for delete - now using IDs
  Set<String> _selectedIds = {};
  bool _isSelectMode = false;
  bool _isSelectAll = false;

  // Platform detection
  bool get _isDesktop => kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  List<dynamic> get _filteredData {
    if (_searchController.text.isEmpty) return _data;
    final query = _searchController.text.toLowerCase();
    return _data.where((item) {
      final regNo = item['reg_no']?.toString().toLowerCase() ?? '';
      final gpsLocation = item['gps_location']?.toString().toLowerCase() ?? '';
      final notes = item['notes']?.toString().toLowerCase() ?? '';
      return regNo.contains(query) ||
          gpsLocation.contains(query) ||
          notes.contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    loadUserData();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
    _searchFocusNode.addListener(_onSearchFocusChange);
  }

  void _onSearchFocusChange() {
    if (_isDesktop && _searchFocusNode.hasFocus) {
      // Auto-select search text on web for better UX
      Future.delayed(Duration(milliseconds: 100), () {
        _searchController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _searchController.text.length,
        );
      });
    }
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
    print("Loading initial data...");
    setState(() {
      _isLoading = true;
      _hasError = false;
      _currentPage = 1;
      _data = [];
      _selectedIds.clear();
      _isSelectMode = false;
      _isSelectAll = false;
    });

    await _fetchData(page: 1, isInitial: true);
  }

  void _loadMoreData() {
    if (!_isLoading && _hasMore && _currentPage < _totalPages) {
      _fetchData(page: _currentPage + 1);
    }
  }

  Future<void> _fetchData({required int page, bool isInitial = false}) async {
    print("Fetching data for page $page");

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

    try {
      final value = await Repository.postApiRawService(
          EndPoints.agentSearchedCarsApi,
          {
            "device_token": deviceId.toString(),
            "page": page,
            "admin_id": userId.toString(),
          }
      );

      UtilClass.hideProgress();
      print("🔵 API Response for page $page: ${value.toString()}");

      dynamic parsed;
      if (value is String) {
        parsed = json.decode(value);
      } else {
        parsed = value;
      }

      print("🟢 Parsed response type: ${parsed.runtimeType}");
      print("🟢 Success status: ${parsed["success"]}");

      if (parsed["success"] == true) {
        final newData = parsed["data"] ?? [];
        final totalPages = parsed["total_pages"] ?? 1;
        final totalCount = parsed["total_count"] ?? 0;

        print("✅ Page $page: Received ${newData.length} items, Total pages: $totalPages, Total count: $totalCount");

        setState(() {
          if (page == 1) {
            _data = List.from(newData);
          } else {
            _data.addAll(newData);
          }
          _currentPage = page;
          _totalPages = totalPages;
          _totalCount = totalCount;
          _hasMore = page < totalPages;
          _isLoading = false;
          _hasError = false;

          // If select all is active, update selection for new data
          if (_isSelectAll) {
            for (final item in newData) {
              final id = item["id"]?.toString();
              if (id != null && id.isNotEmpty) {
                _selectedIds.add(id);
              }
            }
          }
        });

        print("✅ Updated state: ${_data.length} total items, Has more: $_hasMore");
      } else {
        final errorMsg = parsed["message"] ?? "Failed to load data";
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

  // Delete selected records using IDs
  Future<void> _deleteSelectedRecords() async {
    print("i am in _deleteSelectedRecords");

    if (_selectedIds.isEmpty) {
      _showPlatformAlertDialog(context: context, message: "Please select records to delete");
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _buildDeleteConfirmationDialog(),
    );

    if (confirmed != true) return;

    final internet = await UtilClass.checkInternet();
    if (!internet) {
      _showPlatformAlertDialog(context: context, message: Config.kNoInternet);
      return;
    }

    UtilClass.showProgress(context: context);

    try {
      final body = {
        "admin_id": userId,
        "device_token": deviceId,
        "ids": _selectedIds.toList(),
      };
      print("delete Body${body}");

      // 🔍 Print request body
      debugPrint("🟢 Delete Agent Car Search BODY: $body");
      final response = await Repository.postApiRawService(
        EndPoints.deleteAgentCarSearch,
        body,
      );
      print("del response${response}");

      UtilClass.hideProgress();

      dynamic parsed;
      if (response is String) {
        parsed = json.decode(response);
      } else {
        parsed = response;
      }

      print("Delete API Response: ${parsed.toString()}");
      print("IDs sent: ${_selectedIds.toList()}");

      if (parsed["status"] == true) {
        // Remove deleted items from the list
        final deletedCount = _selectedIds.length;
        await _fetchData(page: 1, isInitial: true);
        setState(() {
          _data.removeWhere((item) {
            final id = item["id"]?.toString();
            return id != null && _selectedIds.contains(id);
          });
          _selectedIds.clear();
          _isSelectMode = false;
          _isSelectAll = false;
          _totalCount -= deletedCount;

          // Recalculate total pages
          if (_totalCount > 0) {
            final perPage = 10; // Assuming 10 items per page
            _totalPages = (_totalCount + perPage - 1) ~/ perPage;
          } else {
            _totalPages = 0;
          }
        });

        _showSuccessDialog(deletedCount);
      } else {
        final errorMsg = parsed["message"] ?? "Failed to delete records";
        _showPlatformAlertDialog(context: context, message: errorMsg);
      }
    } catch (e) {
      UtilClass.hideProgress();
      _showPlatformAlertDialog(context: context, message: "Error: ${e.toString()}");
    }
  }

  Widget _buildDeleteConfirmationDialog() {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
          SizedBox(width: 12),
          Text(
            "Confirm Delete",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: _isDesktop ? 18 : 16,
            ),
          ),
        ],
      ),
      content: Container(
        constraints: BoxConstraints(
          maxWidth: _isDesktop ? 400 : double.infinity,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Are you sure you want to delete ${_selectedIds.length} selected record(s)?",
              style: TextStyle(
                fontSize: _isDesktop ? 16 : 14,
                height: 1.4,
              ),
            ),
            if (_selectedIds.length <= 5) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color:Colors.grey),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Selected IDs:",
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                        fontSize: _isDesktop ? 14 : 12,
                      ),
                    ),
                    SizedBox(height: 8),
                    ..._selectedIds.take(5).map((id) => Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text(
                        "• $id",
                        style: TextStyle(
                          fontSize: _isDesktop ? 13 : 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    )),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            "Cancel",
            style: TextStyle(
              fontSize: _isDesktop ? 15 : 14,
              color: Colors.grey[700],
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: _isDesktop ? 24 : 16,
              vertical: _isDesktop ? 12 : 10,
            ),
          ),
          child: Text(
            "Delete",
            style: TextStyle(
              fontSize: _isDesktop ? 15 : 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _showSuccessDialog(int deletedCount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 24),
            SizedBox(width: 12),
            Text(
              "Success",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: _isDesktop ? 18 : 16,
              ),
            ),
          ],
        ),
        content: Text(
          "$deletedCount record(s) deleted successfully",
          style: TextStyle(
            fontSize: _isDesktop ? 16 : 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "OK",
              style: TextStyle(
                fontSize: _isDesktop ? 15 : 14,
                color: Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Toggle selection for a single item using ID
  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        _isSelectAll = false;
        if (_selectedIds.isEmpty) {
          _isSelectMode = false;
        }
      } else {
        _selectedIds.add(id);
        _isSelectMode = true;
      }
    });
  }

  // Toggle select all on current filtered view
  void _toggleSelectAll() {
    setState(() {
      if (_isSelectAll || _selectedIds.length == _filteredData.length) {
        // Deselect all
        _selectedIds.clear();
        _isSelectAll = false;
        _isSelectMode = false;
      } else {
        // Select all in current view
        _selectedIds.clear();
        for (final item in _filteredData) {
          final id = item["id"]?.toString();
          if (id != null && id.isNotEmpty) {
            _selectedIds.add(id);
          }
        }
        _isSelectMode = true;
        _isSelectAll = true;
      }
    });
  }

  // Delete single record using ID
  Future<void> _deleteSingleRecord(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Record"),
        content: Text("Are you sure you want to delete this record?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final internet = await UtilClass.checkInternet();
    if (!internet) {
      _showPlatformAlertDialog(context: context, message: Config.kNoInternet);
      return;
    }

    UtilClass.showProgress(context: context);

    try {
      final body = {
        "admin_id": userId,
        "device_token": deviceId,
        "ids": [id],
      };
      print("delete Body1${body}");
      final response = await Repository.postApiRawService(
          EndPoints.deleteAgentCarSearch,
          body
      );

      UtilClass.hideProgress();

      dynamic parsed;
      if (response is String) {
        parsed = json.decode(response);
      } else {
        parsed = response;
      }

      if (parsed["status"] == true) {
        setState(() {
          _data.removeWhere((item) => item["id"]?.toString() == id);
          _selectedIds.remove(id);
          _totalCount = _totalCount > 0 ? _totalCount - 1 : 0;

          if (_totalCount > 0) {
            final perPage = 10;
            _totalPages = (_totalCount + perPage - 1) ~/ perPage;
          } else {
            _totalPages = 0;
          }
        });

        _showPlatformAlertDialog(
          context: context,
          message: "Record deleted successfully",
        );
      } else {
        final errorMsg = parsed["message"] ?? "Failed to delete record";
        _showPlatformAlertDialog(context: context, message: errorMsg);
      }
    } catch (e) {
      UtilClass.hideProgress();
      _showPlatformAlertDialog(context: context, message: "Error: ${e.toString()}");
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

  void _resetSearch() {
    setState(() {
      _searchController.clear();
      _selectedIds.clear();
      _isSelectMode = false;
      _isSelectAll = false;
      _searchFocusNode.unfocus();
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
              "Loading more data...",
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
          _data.isEmpty ? "No data available" : "All data loaded",
          style: TextStyle(
            fontSize: 14,
            color: const Color(0xFF666666),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final isDesktop = _isDesktop;

    // Platform-specific dimensions
    final double horizontalPadding = isDesktop ? width * 0.03 : width * 0.04;
    final double verticalSpacing = isDesktop ? height * 0.02 : height * 0.015;
    final double cardSpacing = isDesktop ? height * 0.02 : height * 0.015;
    final double buttonHorizontalPadding = isDesktop ? width * 0.02 : width * 0.03;
    final double buttonVerticalPadding = isDesktop ? height * 0.012 : height * 0.012;

    // Font sizes
    final double titleFontSize = isDesktop ? 18.0 : width * 0.045;
    final double bodyFontSize = isDesktop ? 16.0 : width * 0.04;
    final double smallFontSize = isDesktop ? 14.0 : width * 0.035;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Custom header
          if (isDesktop)
            _buildDesktopHeader(width, height)
          else
            CustomAppHeader(
              title: "${"agent_searched_data_title".tr()}",
              onBack: () {
                Navigator.pop(context);
              },
            ),

          SizedBox(height: verticalSpacing),

          // Search Section
          if (isDesktop)
            _buildDesktopSearchSection(width, height, horizontalPadding, buttonHorizontalPadding, buttonVerticalPadding, bodyFontSize)
          else
            _buildMobileSearchSection(width, height, horizontalPadding, buttonHorizontalPadding, buttonVerticalPadding, bodyFontSize),

          SizedBox(height: verticalSpacing * 0.5),

          // Selection Actions Bar (Desktop only - shows when in select mode)
          if (isDesktop && _isSelectMode)
            _buildSelectionActionsBar(width, horizontalPadding, bodyFontSize),

          SizedBox(height: verticalSpacing * 0.5),

          // Summary Info
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Container(
              padding: EdgeInsets.all(isDesktop ? 14 : 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[300]!),
                boxShadow: isDesktop ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ] : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left side - Scrollable status indicators
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: AlwaysScrollableScrollPhysics(),
                      child: Row(
                        children: [
                          // Status indicator
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            margin: EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: _isLoading ? Colors.orange.withOpacity(0.1) :
                              _hasError ? Colors.red.withOpacity(0.1) :
                              Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
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
                                  _isLoading ? Icons.sync :
                                  _hasError ? Icons.error_outline :
                                  Icons.check_circle,
                                  size: 14,
                                  color: _isLoading ? Colors.orange :
                                  _hasError ? Colors.red :
                                  Colors.green,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  _isLoading ? 'Loading' : _hasError ? 'Error' : 'Ready',
                                  style: TextStyle(
                                    fontSize: smallFontSize,
                                    color: _isLoading ? Colors.orange :
                                    _hasError ? Colors.red :
                                    Colors.green,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Selection count
                          if (_isSelectMode)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              margin: EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.blue.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_box,
                                    size: 14,
                                    color: Colors.blue[700],
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    "${_selectedIds.length} selected",
                                    style: TextStyle(
                                      fontSize: smallFontSize,
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Filtered count (if searching)
                          if (_searchController.text.isNotEmpty && _filteredData.length != _data.length)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              margin: EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.amber.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.filter_list,
                                    size: 14,
                                    color: Colors.amber[700],
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    "Showing: ${_filteredData.length}",
                                    style: TextStyle(
                                      fontSize: smallFontSize,
                                      color: Colors.amber[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Total count
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            margin: EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.list,
                                  size: 14,
                                  color: Colors.grey[700],
                                ),
                                SizedBox(width: 6),
                                Text(
                                  "Total: $_totalCount",
                                  style: TextStyle(
                                    fontSize: smallFontSize,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Loading progress (if loading)
                          if (_isLoading && _currentPage > 1)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              margin: EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.blue.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    "Loading more...",
                                    style: TextStyle(
                                      fontSize: smallFontSize,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Empty state indicator
                          if (_data.isEmpty && !_isLoading && !_hasError)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              margin: EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    "No records found",
                                    style: TextStyle(
                                      fontSize: smallFontSize,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Error state (if any)
                          if (_hasError)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              margin: EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.red.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning,
                                    size: 14,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    "Connection Error",
                                    style: TextStyle(
                                      fontSize: smallFontSize,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(width: 16),

                  // Right side - Page info (fixed, not scrollable)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.purple.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.pageview,
                          size: 14,
                          color: Colors.purple[700],
                        ),
                        SizedBox(width: 6),
                        Text(
                          "Page $_currentPage/$_totalPages",
                          style: TextStyle(
                            fontSize: smallFontSize,
                            color: Colors.purple[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: verticalSpacing),

          // Main Content Area
          Expanded(
            child: _isLoading && _data.isEmpty
                ? _buildInitialLoading(width, height, titleFontSize, smallFontSize)
                : _hasError && _data.isEmpty
                ? _buildErrorState(width, height, titleFontSize, bodyFontSize)
                : RefreshIndicator(
              onRefresh: () async {
                _refreshData();
              },
              child: _filteredData.isEmpty
                  ? _buildNoDataView(width, height, titleFontSize, bodyFontSize, smallFontSize)
                  : isDesktop
                  ? _buildDesktopGridView(width, height, horizontalPadding, bodyFontSize, smallFontSize, cardSpacing)
                  : _buildMobileListView(width, height, horizontalPadding, bodyFontSize, smallFontSize, cardSpacing),
            ),
          ),

          // Mobile selection actions (floating at bottom)
          if (!isDesktop && _isSelectMode)
            _buildMobileSelectionActions(),
        ],
      ),
    );
  }

  // Desktop Header with Delete Button
  Widget _buildDesktopHeader(double width, double height) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: width * 0.04, vertical: 18),
      decoration: BoxDecoration(
        color: MyColors.appThemeDark,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      "Back",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SizedBox(width: 24),

          // Title
          Expanded(
            child: Text(
              "${"agent_searched_data_title".tr()}",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),

          // User info
          if (userName.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.person_outline, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    userName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),

          SizedBox(width: 16),

          // Delete button (only shows when items are selected)
          if (_selectedIds.isNotEmpty && _isSelectMode)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: AnimatedContainer(
                duration: Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red[600]!, Colors.red[800]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.4),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _deleteSelectedRecords,
                    borderRadius: BorderRadius.circular(10),
                    onHover: (hovered) {},
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "Delete (${_selectedIds.length})",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_selectedIds.isNotEmpty) SizedBox(width: 8),
                          if (_selectedIds.isNotEmpty)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                "${_selectedIds.length}",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
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

  // Desktop Grid View
  Widget _buildDesktopGridView(double width, double height, double horizontalPadding,
      double fontSize, double smallFontSize, double spacing) {
    final items = _filteredData;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Scrollbar(
        controller: _scrollController,
        child: GridView.builder(
          controller: _scrollController,
          padding: EdgeInsets.only(top: 20, bottom: 40),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: width > 1200 ? 3 : 2,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,

            // ✅ FIX: increase card height explicitly
            mainAxisExtent: width > 1200 ? 360 : 400,
          ),
          itemCount: items.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == items.length) {
              if (_isLoading) {
                return _buildGridLoadingIndicator();
              } else if (!_hasMore) {
                return _buildGridEndOfList();
              } else {
                return SizedBox.shrink();
              }
            }

            final item = items[index];
            return _buildDesktopGridCardItem(item, width, fontSize, smallFontSize);
          },
        ),
      ),
    );
  }
  // Desktop Grid Card Item
  Widget _buildDesktopGridCardItem(dynamic item, double width, double fontSize, double smallFontSize) {
    String getValue(String key) {
      final value = item[key]?.toString();
      return (value == null || value.isEmpty || value == '-') ? "-" : value;
    }

    final bool isFound = item["found"]?.toString() == "1";
    final String? id = item["id"]?.toString();
    final bool isSelected = id != null && _selectedIds.contains(id);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (_isSelectMode && id != null) {
            _toggleSelection(id);
          }
        },
        onLongPress: () {
          if (id != null) {
            _toggleSelection(id);
            if (!_isSelectMode) {
              setState(() {
                _isSelectMode = true;
              });
            }
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: isSelected ? Colors.blue[400]! : Colors.grey[200]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // ✅ IMPORTANT
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with checkbox
                    Row(
                      children: [
                        if (_isSelectMode)
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.blue[400]! : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected ? Colors.blue[400]! : Colors.grey[400]!,
                                width: 1.5,
                              ),
                            ),
                            child: isSelected
                                ? Icon(Icons.check, size: 16, color: Colors.white)
                                : null,
                          ),
                        if (_isSelectMode) SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      getValue("reg_no"),
                                      style: TextStyle(
                                        fontSize: fontSize * 1.1,
                                        fontWeight: FontWeight.w600,
                                        color: isFound ? Colors.green : Colors.red,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (!_isSelectMode && id != null)
                                    MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: GestureDetector(
                                        onTap: () => _deleteSingleRecord(id),
                                        child: Container(
                                          padding: EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.red[50],
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Icon(
                                            Icons.delete_outline_rounded,
                                            color: Colors.red[600],
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    "S.No: ${getValue("s_no")}",
                                    style: TextStyle(
                                      fontSize: smallFontSize,
                                      color: const Color(0xFF666666),
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Text(
                                    "Car ID: ${getValue("id")}",
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
                      ],
                    ),

                    Divider(height: 20, color: Colors.grey[200]),

                    // Details - Added Car ID row
                    _buildDesktopDetailRow("Car ID:", getValue("id"), smallFontSize),
                    SizedBox(height: 8),
                    _buildDesktopDetailRow("GPS Location:", getValue("gps_location"), smallFontSize),
                    SizedBox(height: 8),
                    _buildDesktopDetailRow("Location Details:", getValue("location_details"), smallFontSize),
                    SizedBox(height: 8),
                    _buildDesktopDetailRow("Notes:", getValue("notes"), smallFontSize),
                    SizedBox(height: 8),
                    _buildDesktopDetailRow("Searched at:", getValue("searched_at"), smallFontSize),

                    const SizedBox(height: 12), // ✅ instead of Spacer()

                    // Status indicator
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isFound ? Colors.green[50] : Colors.red[50],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isFound ? Colors.green[100]! : Colors.red[100]!,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isFound ? Icons.check_circle : Icons.cancel,
                                size: 12,
                                color: isFound ? Colors.green : Colors.red,
                              ),
                              SizedBox(width: 4),
                              Text(
                                isFound ? "Found" : "Not Found",
                                style: TextStyle(
                                  fontSize: smallFontSize * 0.9,
                                  color: isFound ? Colors.green : Colors.red,
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

              // Selection overlay
              if (isSelected && _isSelectMode)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.blue[400],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.check, size: 16, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopDetailRow(String label, String value, double fontSize) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: const Color(0xFF555555),
              fontSize: fontSize,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              color: const Color(0xFF222222),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildGridLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: MyColors.appThemeDark,
            strokeWidth: 2,
          ),
          SizedBox(height: 12),
          Text(
            "Loading...",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridEndOfList() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, color: Colors.green, size: 32),
          SizedBox(height: 8),
          Text(
            "All data loaded",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Mobile List View
  Widget _buildMobileListView(double width, double height, double horizontalPadding,
      double fontSize, double smallFontSize, double spacing) {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.only(
        left: horizontalPadding,
        right: horizontalPadding,
        bottom: _isSelectMode ? 80 : 100,
        top: 12,
      ),
      itemCount: _filteredData.length + 1,
      itemBuilder: (context, index) {
        if (index == _filteredData.length) {
          if (_isLoading) {
            return _buildLoadingIndicator();
          } else if (!_hasMore) {
            return _buildEndOfList();
          } else {
            return SizedBox.shrink();
          }
        }

        final item = _filteredData[index];
        return _buildMobileCardItem(item, width, height, fontSize, smallFontSize, spacing, index);
      },
    );
  }

  // Mobile Card Item with selection
  Widget _buildMobileCardItem(dynamic item, double width, double height, double fontSize,
      double smallFontSize, double spacing, int index) {
    String getValue(String key) {
      final value = item[key]?.toString();
      return (value == null || value.isEmpty || value == '-') ? "-" : value;
    }

    final bool isFound = item["found"]?.toString() == "1";
    final String? id = item["id"]?.toString();
    final bool isSelected = id != null && _selectedIds.contains(id);

    return Container(
      margin: EdgeInsets.only(bottom: spacing),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: isSelected ? Colors.blue[400]! : Colors.grey[200]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.all(width * 0.04),
            child: Column(
              children: [
                // Header with selection checkbox
                Row(
                  children: [
                    if (_isSelectMode)
                      GestureDetector(
                        onTap: () {
                          if (id != null) {
                            _toggleSelection(id);
                          }
                        },
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blue[400]! : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected ? Colors.blue[400]! : Colors.grey[400]!,
                              width: 1.5,
                            ),
                          ),
                          child: isSelected
                              ? Icon(Icons.check, size: 18, color: Colors.white)
                              : null,
                        ),
                      ),
                    if (_isSelectMode) SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "${"registration_no".tr()}:",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF333333),
                                  fontSize: fontSize,
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  getValue("reg_no"),
                                  style: TextStyle(
                                    fontSize: fontSize,
                                    color: isFound ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                "S.No: ${getValue("s_no")}",
                                style: TextStyle(
                                  fontSize: smallFontSize,
                                  color: const Color(0xFF666666),
                                ),
                              ),
                              SizedBox(width: 16),
                              Text(
                                "Car ID: ${getValue("id")}",
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
                    // Delete button (only when not in select mode)
                    if (!_isSelectMode && id != null)
                      GestureDetector(
                        onTap: () => _deleteSingleRecord(id),
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.red[600],
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),

                Divider(height: 20, color: Colors.grey[200]),

                // Details - Added Car ID row
                _buildMobileDetailRow("${"car_id".tr()}:", getValue("id"), width, fontSize),
                _buildMobileDetailRow("${"gps_location".tr()}:", getValue("gps_location"), width, fontSize),
                _buildMobileDetailRow("${"location_details".tr()}:", getValue("location_details"), width, fontSize),
                _buildMobileDetailRow("${"notes".tr()}:", getValue("notes"), width, fontSize),
                _buildMobileDetailRow("${"searched_at".tr()}:", getValue("searched_at"), width, fontSize),
              ],
            ),
          ),

          // Selection overlay
          if (isSelected && _isSelectMode)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.blue[400],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.check, size: 14, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileDetailRow(String label, String value, double width, double fontSize) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: width * 0.35,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: const Color(0xFF555555),
                fontSize: fontSize * 0.9,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: fontSize * 0.9,
                color: const Color(0xFF222222),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Mobile Selection Actions (Bottom bar)
  Widget _buildMobileSelectionActions() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Select All
          Expanded(
            child: GestureDetector(
              onTap: _toggleSelectAll,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isSelectAll ? Icons.check_box : Icons.check_box_outline_blank,
                      color: Colors.blue[700],
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      _isSelectAll ? "Deselect All" : "Select All",
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SizedBox(width: 12),

          // Delete Button
          Expanded(
            child: GestureDetector(
              onTap: _deleteSelectedRecords,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red[600]!, Colors.red[800]!],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Delete (${_selectedIds.length})",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SizedBox(width: 12),

          // Cancel Button
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedIds.clear();
                _isSelectMode = false;
                _isSelectAll = false;
              });
            },
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.close, color: Colors.grey[700], size: 24),
            ),
          ),
        ],
      ),
    );
  }

  // Selection Actions Bar for Desktop
  Widget _buildSelectionActionsBar(double width, double horizontalPadding, double fontSize) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.blue[700], size: 24),
          SizedBox(width: 12),
          Text(
            "${_selectedIds.length} item(s) selected",
            style: TextStyle(
              fontSize: fontSize,
              color: Colors.blue[700],
              fontWeight: FontWeight.w600,
            ),
          ),

          Spacer(),

          // Select All checkbox
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _toggleSelectAll,
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _isSelectAll ? Colors.blue[700] : Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _isSelectAll ? Colors.blue : Colors.grey[400]!,
                        width: 1.5,
                      ),
                    ),
                    child: _isSelectAll
                        ? Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                  SizedBox(width: 8),
                  Text(
                    _isSelectAll ? "Deselect All" : "Select All",
                    style: TextStyle(
                      fontSize: fontSize * 0.9,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(width: 20),

          // Delete Button
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _deleteSelectedRecords,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Delete Selected",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: fontSize * 0.95,
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "${_selectedIds.length}",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: fontSize * 0.8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SizedBox(width: 12),

          // Cancel Button
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedIds.clear();
                  _isSelectMode = false;
                  _isSelectAll = false;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Cancel",
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                    fontSize: fontSize * 0.95,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }



  // Desktop Search Section
  Widget _buildDesktopSearchSection(double width, double height, double horizontalPadding,
      double buttonHorizontalPadding, double buttonVerticalPadding, double fontSize) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "🔍 Search & Filter",
                style: TextStyle(
                  fontSize: fontSize * 1.1,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF444444),
                ),
              ),
              // Selection mode toggle
              if (_data.isNotEmpty)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_isSelectMode) {
                          _selectedIds.clear();
                          _isSelectMode = false;
                          _isSelectAll = false;
                        } else {
                          _isSelectMode = true;
                        }
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: _isSelectMode ? Colors.blue[100] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isSelectMode ? Colors.blue[300]! : Colors.grey[300]!,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isSelectMode ? Icons.done_all : Icons.select_all,
                            size: 20,
                            color: _isSelectMode ? Colors.blue[700] : Colors.grey[700],
                          ),
                          SizedBox(width: 8),
                          Text(
                            _isSelectMode ? "Selection Mode" : "Select Multiple",
                            style: TextStyle(
                              fontSize: fontSize * 0.95,
                              color: _isSelectMode ? Colors.blue[700] : Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),

          SizedBox(height: 16),

          // Search row
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[300]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: "Search by registration number, location, or notes...",
                      hintStyle: TextStyle(
                        color: const Color(0xFF888888),
                        fontSize: fontSize,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      prefixIcon: Icon(Icons.search_rounded, size: 24, color: Colors.grey[600]),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[500]),
                        onPressed: () => _resetSearch(),
                      )
                          : null,
                    ),
                    style: TextStyle(fontSize: fontSize),
                    onChanged: (value) => setState(() {}),
                    onSubmitted: (value) {
                      FocusScope.of(context).unfocus();
                    },
                  ),
                ),
              ),

              SizedBox(width: 12),

              // Search Button
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    FocusScope.of(context).unfocus();
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [MyColors.greenBackground, Colors.green[700]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, size: 22, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          "${"search".tr()}",
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

              SizedBox(width: 8),

              // Reset Button
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _resetSearch,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.refresh_rounded, size: 22, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          "${"reset".tr()}",
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
            ],
          ),

          // Search tips
          if (_searchController.text.isNotEmpty && _filteredData.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                "No results found. Try different keywords.",
                style: TextStyle(
                  fontSize: fontSize * 0.9,
                  color: Colors.orange[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Mobile Search Section
  Widget _buildMobileSearchSection(double width, double height, double horizontalPadding,
      double buttonHorizontalPadding, double buttonVerticalPadding, double fontSize) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        children: [
          // Search row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "${"search".tr()}...",
                    hintStyle: TextStyle(
                      color: const Color(0xFF666666),
                      fontSize: fontSize,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: MyColors.appThemeDark, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                  ),
                  style: TextStyle(fontSize: fontSize),
                  onChanged: (value) => setState(() {}),
                ),
              ),
              SizedBox(width: 8),
              // Selection mode toggle
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (_isSelectMode) {
                      _selectedIds.clear();
                      _isSelectMode = false;
                      _isSelectAll = false;
                    } else {
                      _isSelectMode = true;
                    }
                  });
                },
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isSelectMode ? Colors.blue[100] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _isSelectMode ? Icons.done_all : Icons.checklist,
                    color: _isSelectMode ? Colors.blue[700] : Colors.grey[700],
                    size: 24,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 8),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    FocusScope.of(context).unfocus();
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: MyColors.greenBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        "${"search".tr()}",
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
              SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: _resetSearch,
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        "${"reset".tr()}",
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
          ),
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
          SizedBox(height: height * 0.03),
          Text(
            "Loading data...",
            style: TextStyle(
              fontSize: titleFontSize,
              color: const Color(0xFF444444),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: height * 0.01),
          Text(
            "Please wait while we fetch your records",
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
  Widget _buildErrorState(double width, double height, double titleFontSize, double fontSize) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: _isDesktop ? 80 : width * 0.25,
              color: Colors.red[400],
            ),
            SizedBox(height: height * 0.03),
            Text(
              "Oops! Something went wrong",
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF444444),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: height * 0.015),
            Text(
              _errorMessage,
              style: TextStyle(
                fontSize: fontSize * 0.9,
                color: const Color(0xFF666666),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: height * 0.03),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _retryAPI,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: _isDesktop ? 32 : width * 0.1,
                    vertical: _isDesktop ? 16 : height * 0.02,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [MyColors.appThemeDark, Colors.blue[800]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Text(
                        "Try Again",
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
          ],
        ),
      ),
    );
  }

  // No Data View
  Widget _buildNoDataView(double width, double height, double titleFontSize, double fontSize, double smallFontSize) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: _isDesktop ? 100 : width * 0.3,
              color: Colors.grey[400],
            ),
            SizedBox(height: height * 0.03),
            Text(
              _data.isEmpty ? "No Records Found" : "No Search Results",
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF444444),
              ),
            ),
            SizedBox(height: height * 0.015),
            Text(
              _data.isEmpty
                  ? "There are no records to display."
                  : "No records match your search criteria.",
              style: TextStyle(
                fontSize: fontSize * 0.9,
                color: const Color(0xFF666666),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: height * 0.025),
            if (_hasError)
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _retryAPI,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: _isDesktop ? 24 : width * 0.08,
                      vertical: _isDesktop ? 14 : height * 0.018,
                    ),
                    decoration: BoxDecoration(
                      color: MyColors.appThemeDark,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          "Retry",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: fontSize * 0.95,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}