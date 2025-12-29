import 'dart:convert';
import 'dart:io' show Platform;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:repo_agent_application/models/profile_model.dart';
import 'package:repo_agent_application/utils/my_colors.dart';
import '../../components/custom_app_header.dart';
import '../../data/prefernces.dart';
import '../../services/end_points.dart';
import '../../services/repository.dart';
import '../../utils/config.dart';
import '../../utils/util_class.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _showPasswordCard = false;
  bool _isLoading = false;
  bool _isProfileLoading = true;

  String userName = "";
  String deviceId = "";
  String userId = "";

  bool _hasError = false;
  String _errorMessage = "";

  ProfileModel? _profile;

  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // Platform detection helpers
  bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  @override
  void initState() {
    super.initState();
    loadUserData();
    getProfileDataAPI();
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

  void updatePasswordAPI() async {
    final password = _newPasswordController.text.trim();

    final internet = await UtilClass.checkInternet();

    if (!internet) {
      UtilClass.showAlertDialog(context: context, message: Config.kNoInternet);
      return;
    }

    try {
      UtilClass.showProgress(context: context);

      final response = await Repository.postApiRawService(
        EndPoints.changePasswordApi,
        {
          "password": password,
          'device_token': deviceId.toString(),
          'admin_id': userId.toString(),
        },
      );

      UtilClass.hideProgress();
      print("updatePass $response");

      if (response["success"] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response["message"] ?? "Password updated successfully"),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );

        // 🔥 reset UI
        _handleCancelPassword();
      } else {
        UtilClass.showAlertDialog(
            context: context,
            message: response["message"] ?? "Password update failed"
        );
      }

    } catch (e) {
      UtilClass.hideProgress();
      UtilClass.showAlertDialog(context: context, message: e.toString());
    }
  }

  void _handleEditProfilePress() {
    setState(() {
      _showPasswordCard = !_showPasswordCard;
    });
  }

  void _handleCancelPassword() {
    setState(() {
      _showPasswordCard = false;
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    });
  }

  Future<void> _handleUpdatePassword() async {
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (newPassword.isEmpty) {
      _showErrorDialog('Please enter new password');
      return;
    }

    if (newPassword.length < 6) {
      _showErrorDialog('Password must be at least 6 characters long');
      return;
    }

    if (newPassword != confirmPassword) {
      _showErrorDialog('New password and confirm password do not match');
      return;
    }

    setState(() => _isLoading = true);
    updatePasswordAPI();
    setState(() => _isLoading = false);
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${"error".tr()}'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('${"ok".tr()}'),
            ),
          ],
        );
      },
    );
  }

  void getProfileDataAPI() async {
    setState(() {
      _isProfileLoading = true;
      _hasError = false;
    });

    final internet = await UtilClass.checkInternet();

    if (!internet) {
      setState(() {
        _isProfileLoading = false;
        _profile = null;
        _hasError = true;
        _errorMessage = Config.kNoInternet;
      });
      return;
    }

    try {
      final response = await Repository.postApiRawService(
        EndPoints.profileApi,
        {
          "device_token": deviceId.toString(),
          'admin_id': userId.toString(),
        },
      );

      if (response["success"] == true && response["data"] != null) {
        setState(() {
          _profile = ProfileModel.fromJson(response["data"]);
          _isProfileLoading = false;
        });
      } else {
        setState(() {
          _profile = null;
          _isProfileLoading = false;
          _hasError = true;
          _errorMessage = response["message"] ?? "No data found";
        });
      }
    } catch (e) {
      setState(() {
        _profile = null;
        _isProfileLoading = false;
        _hasError = true;
        _errorMessage = "Something went wrong";
      });
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
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
    final double width = MediaQuery.of(context).size.width;
    final double height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: Column(
        children: [
          CustomAppHeader(
            title: '${"edit_profile".tr()}',
            onBack: () {
              Navigator.pop(context);
            },
          ),

          Expanded(
            child: _isProfileLoading
                ? const Center(child: CircularProgressIndicator())
                : _profile == null
                ? _buildMobileEmptyState(width, height)
                : SingleChildScrollView(
              padding: EdgeInsets.symmetric(vertical: height * 0.02),
              child: Column(
                children: [
                  Container(
                    width: width * 0.9,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(width * 0.04),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(width * 0.05),
                    child: Column(
                      children: [
                        _buildMobileInfoRow("${"name".tr()}", _profile!.adminName, width, height),
                        _buildMobileInfoRow("${"email".tr()}", _profile!.email, width, height),
                        _buildMobileInfoRow("${"mobile".tr()}", _profile!.mobileNumber, width, height),
                        _buildMobileInfoRow("${"address".tr()}", _profile!.address, width, height),
                        _buildMobileInfoRow("${"joining_date".tr()}", _profile!.joiningDate, width, height),

                        SizedBox(height: height * 0.03),

                        _buildMobileEditProfileButton(width, height),

                        if (_showPasswordCard)
                          _buildMobilePasswordChangeCard(width, height),
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

  // Windows/Desktop UI
  Widget _buildDesktopUI() {
    final size = MediaQuery.of(context).size;
    final isWideScreen = size.width > 1200;

    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          '${"edit_profile".tr()}',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white
          ),
        ),
        backgroundColor: MyColors.appThemeDark1,
        elevation: 2,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: 24,color: Colors.white,),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: _isProfileLoading
          ? Center(
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
              '${"loading_profile".tr()}',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      )
          : _profile == null
          ? _buildDesktopEmptyState()
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isWideScreen ? 1200 : 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${"personal_information".tr()}',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _handleEditProfilePress,
                        icon: Icon(
                          _showPasswordCard ? Icons.lock_open : Icons.lock,
                          size: 20,
                        ),
                        label: Text(
                          _showPasswordCard ? '${"hide_password_change".tr()}' : '${"change_password".tr()}',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MyColors.appThemeDark,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${"manage_your_profile_information".tr()}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 32),

                  // Profile Card
                  Container(
                    width: double.infinity,
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
                      children: [
                        // Profile Header
                        Row(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: MyColors.appThemeDark.withOpacity(0.1),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: MyColors.appThemeDark,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.person,
                                size: 40,
                                color: MyColors.appThemeDark,
                              ),
                            ),
                            SizedBox(width: 24),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _profile!.adminName,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    _profile!.email,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "User ID: $userId",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 32),

                        // Profile Details Grid
                        GridView.count(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          crossAxisCount: isWideScreen ? 3 : 2,
                          crossAxisSpacing: 24,
                          mainAxisSpacing: 24,
                          childAspectRatio: 3,
                          children: [
                            _buildDesktopInfoItem(
                              icon: Icons.phone,
                              label: "${"mobile".tr()}",
                              value: _profile!.mobileNumber,
                            ),
                            _buildDesktopInfoItem(
                              icon: Icons.location_on,
                              label: "${"address".tr()}",
                              value: _profile!.address,
                            ),
                            _buildDesktopInfoItem(
                              icon: Icons.calendar_today,
                              label: "${"joining_date".tr()}",
                              value: _profile!.joiningDate,
                            ),
                          ],
                        ),
                        SizedBox(height: 32),

                        // Password Change Section (if visible)
                        if (_showPasswordCard)
                          _buildDesktopPasswordChangeCard(),
                      ],
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

  // Mobile Info Row
  Widget _buildMobileInfoRow(
      String label,
      String value,
      double width,
      double height,
      ) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: height * 0.015),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE3E3E3), width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: width * 0.35,
            child: Text(
              label,
              style: TextStyle(
                fontSize: width * 0.04,
                color: const Color(0xFF555555),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: width * 0.044,
                color: const Color(0xFF333333),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Desktop Info Item
  Widget _buildDesktopInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          SizedBox(width: 16),
          Expanded(
            child: Column(
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
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Mobile Edit Profile Button
  Widget _buildMobileEditProfileButton(double width, double height) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isLoading ? null : _handleEditProfilePress,
        borderRadius: BorderRadius.circular(width * 0.03),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: height * 0.02),
          decoration: BoxDecoration(
            color: _isLoading ? const Color(0xFFCCCCCC) : MyColors.appThemeDark,
            borderRadius: BorderRadius.circular(width * 0.03),
          ),
          child: Center(
            child: Text(
              _isLoading ? 'Updating...' : "${"update_password".tr()}",
              style: TextStyle(
                fontSize: width * 0.045,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Mobile Password Change Card
  Widget _buildMobilePasswordChangeCard(double width, double height) {
    return Container(
      margin: EdgeInsets.only(top: height * 0.03),
      padding: EdgeInsets.all(width * 0.04),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(width * 0.03),
        border: Border.all(
          color: const Color(0xFFE3E3E3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            "${"change_password".tr()}",
            style: TextStyle(
              fontSize: width * 0.05,
              fontWeight: FontWeight.bold,
              color: MyColors.appThemeDark,
            ),
          ),
          SizedBox(height: height * 0.02),

          // New Password Field
          _buildMobilePasswordInputField(
            label: "${"new_password".tr()}",
            controller: _newPasswordController,
            width: width,
            height: height,
          ),
          SizedBox(height: height * 0.02),

          // Confirm Password Field
          _buildMobilePasswordInputField(
            label: "${"confirm_password".tr()}",
            controller: _confirmPasswordController,
            width: width,
            height: height,
          ),
          SizedBox(height: height * 0.01),

          // Buttons
          _buildMobilePasswordButtons(width, height),
        ],
      ),
    );
  }

  // Desktop Password Change Card
  Widget _buildDesktopPasswordChangeCard() {
    return Container(
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: MyColors.appThemeDark.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock, color: MyColors.appThemeDark, size: 28),
              SizedBox(width: 12),
              Text(
                "${"change_password".tr()}",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            "${"password_change_instructions".tr()}",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 32),

          // Password Fields
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${"new_password".tr()}",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: _newPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: '${"enter_new_password".tr()}',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: MyColors.appThemeDark, width: 2),
                        ),
                      ),
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${"confirm_password".tr()}",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: '${"confirm_new_password".tr()}',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: MyColors.appThemeDark, width: 2),
                        ),
                      ),
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 32),

          // Password Requirements
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[100]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${"password_requirements".tr()}",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[800],
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "${"password_min_length".tr()}",
                        style: TextStyle(fontSize: 13, color: Colors.blue[700]),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 32),

          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: _handleCancelPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                  foregroundColor: Colors.grey[800],
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('${"cancel".tr()}'),
              ),
              SizedBox(width: 16),
              ElevatedButton(
                onPressed: _handleUpdatePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MyColors.appThemeDark,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : Text('${"update".tr()}'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Mobile Password Input Field
  Widget _buildMobilePasswordInputField({
    required String label,
    required TextEditingController controller,
    required double width,
    required double height,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: width * 0.04,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF555555),
          ),
        ),
        SizedBox(height: height * 0.008),
        TextField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(
            hintText: 'Enter $label',
            hintStyle: TextStyle(
              color: const Color(0xFF999999),
              fontSize: width * 0.04,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.all(width * 0.04),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(width * 0.02),
              borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(width * 0.02),
              borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
            ),
          ),
          style: TextStyle(
            fontSize: width * 0.04,
            color: const Color(0xFF333333),
          ),
        ),
      ],
    );
  }

  // Mobile Password Buttons
  Widget _buildMobilePasswordButtons(double width, double height) {
    return Row(
      children: [
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _handleCancelPassword,
              borderRadius: BorderRadius.circular(width * 0.02),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: height * 0.018),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C757D),
                  borderRadius: BorderRadius.circular(width * 0.02),
                ),
                child: Center(
                  child: Text(
                    "${"cancel".tr()}",
                    style: TextStyle(
                      fontSize: width * 0.04,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: width * 0.02),
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _handleUpdatePassword,
              borderRadius: BorderRadius.circular(width * 0.02),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: height * 0.018),
                decoration: BoxDecoration(
                  color: MyColors.appThemeDark,
                  borderRadius: BorderRadius.circular(width * 0.02),
                ),
                child: Center(
                  child: Text(
                    "${"update".tr()}",
                    style: TextStyle(
                      fontSize: width * 0.04,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Mobile Empty State
  Widget _buildMobileEmptyState(double width, double height) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/no-data.png',
            width: width * 0.55,
            height: height * 0.25,
            opacity: const AlwaysStoppedAnimation(0.8),
            fit: BoxFit.contain,
          ),
          SizedBox(height: height * 0.03),
          Text(
            _errorMessage.isNotEmpty ? _errorMessage : "No data available",
            style: TextStyle(
              fontSize: width * 0.045,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: height * 0.03),
          ElevatedButton(
            onPressed: getProfileDataAPI,
            child: Text("${"retry".tr()}"),
          ),
        ],
      ),
    );
  }

  // Desktop Empty State
  Widget _buildDesktopEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 24),
          Text(
            _errorMessage.isNotEmpty ? _errorMessage : "${"no_profile_data".tr()}",
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: getProfileDataAPI,
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
}