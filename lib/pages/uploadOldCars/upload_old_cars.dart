import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../components/custom_app_header.dart';
import 'package:repo_agent_application/utils/my_colors.dart';
import '../../data/prefernces.dart';
import '../../services/end_points.dart';
import '../../services/repository.dart';
import '../../utils/config.dart';
import '../../utils/util_class.dart';

class UploadOldCarsScreen extends StatefulWidget {
  const UploadOldCarsScreen({Key? key}) : super(key: key);

  @override
  State<UploadOldCarsScreen> createState() => _UploadOldCarsScreenState();
}

class _UploadOldCarsScreenState extends State<UploadOldCarsScreen> {
  String _fileName = "No file chosen";
  String? _filePath;
  PlatformFile? _selectedFile;
  bool _isUploading = false;

  String userName = "";
  String deviceId = "";
  String userId = "";

  // Platform detection for Windows/Web
  bool get _isDesktop => kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  Future<void> _chooseFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        // Better dialog title for desktop/web
        dialogTitle: _isDesktop ? 'Select Excel or CSV File' : null,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        // Validate file extension
        final validExtensions = ['.xlsx', '.xls', '.csv'];
        final fileExtension = file.extension?.toLowerCase() ?? '';
        final fileName = file.name.toLowerCase();

        bool isValid = false;
        for (var ext in validExtensions) {
          if (fileName.endsWith(ext)) {
            isValid = true;
            break;
          }
        }

        if (!isValid) {
          _showPlatformAlertDialog(
              context: context,
              message: "Please select only Excel (.xlsx, .xls) or CSV (.csv) files."
          );
          return;
        }

        setState(() {
          _fileName = file.name;
          _filePath = file.path;
          _selectedFile = file;
        });

        print("Selected file: ${file.name}, size: ${file.size}, path: ${file.path}");
      } else {
        // User canceled the picker
        print("User cancelled file picker");
      }
    } catch (e) {
      print("Error picking file: $e");
      _showPlatformAlertDialog(
          context: context,
          message: "Error selecting file: $e"
      );
    }
  }

  Future<String?> _convertFileToBase64(String? filePath) async {
    if (filePath == null) return null;

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print("File does not exist at path: $filePath");
        return null;
      }

      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);
      print("File converted to base64, size: ${base64String.length} characters");
      return base64String;
    } catch (e) {
      print("Error converting file to base64: $e");
      return null;
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

  void callUploadCarRecordAPI() async {
    // Validate file is selected
    if (_selectedFile == null || _filePath == null) {
      _showPlatformAlertDialog(
          context: context,
          message: "Please select a file first."
      );
      return;
    }

    // Validate file extension again
    final fileName = _selectedFile!.name.toLowerCase();
    final validExtensions = ['.xlsx', '.xls', '.csv'];
    bool isValid = false;
    for (var ext in validExtensions) {
      if (fileName.endsWith(ext)) {
        isValid = true;
        break;
      }
    }

    if (!isValid) {
      _showPlatformAlertDialog(
          context: context,
          message: "Invalid file type. Please select only Excel (.xlsx, .xls) or CSV (.csv) files."
      );
      return;
    }

    // Check internet connection
    final internet = await UtilClass.checkInternet();
    if (!internet) {
      _showPlatformAlertDialog(context: context, message: Config.kNoInternet);
      return;
    }

    print("Device ID: ${deviceId}");

    setState(() {
      _isUploading = true;
    });

    try {
      // Show progress indicator
      UtilClass.showProgress(context: context);

      // Convert file to base64
      final base64String = await _convertFileToBase64(_filePath);

      if (base64String == null) {
        throw Exception("Failed to convert file to base64");
      }

      print("Sending API request...");

      // Prepare request body
      final requestBody = {
        "file_name": _selectedFile!.name,
        "file_base64": base64String.toString(),
        "device_token": deviceId.toString(),
        'admin_id': userId.toString(),
      };

      print("Request body prepared, file name: ${_selectedFile!.name}");
      print("Base64 string length: ${base64String.length}");
      print("doc body: ${requestBody}");

      // Call API
      final value = await Repository.postApiRawService(
          EndPoints.uploadOldCarsApi,
          requestBody
      );

      UtilClass.hideProgress();
      setState(() {
        _isUploading = false;
      });

      print("Upload API Response: $value");

      // Check response
      if (value != null) {
        if (value is Map) {
          if (value["status"] == true || value["success"] == true) {
            // ✅ Show success message
            _showPlatformSuccessMessage("File uploaded successfully!");

            // Reset file selection after successful upload
            setState(() {
              _fileName = "No file chosen";
              _filePath = null;
              _selectedFile = null;
            });
          } else {
            // Show error message from API
            final errorMessage = value["message"] ?? "Upload failed. Please try again.";
            _showPlatformAlertDialog(context: context, message: errorMessage.toString());
          }
        } else {
          // Handle different response format
          print("Unexpected response format: $value");
          _showPlatformSuccessMessage("File uploaded successfully!");

          // Reset file selection
          setState(() {
            _fileName = "No file chosen";
            _filePath = null;
            _selectedFile = null;
          });
        }
      } else {
        _showPlatformAlertDialog(
            context: context,
            message: "No response from server."
        );
      }
    } catch (e) {
      UtilClass.hideProgress();
      setState(() {
        _isUploading = false;
      });

      print("Upload error: $e");
      _showPlatformAlertDialog(
          context: context,
          message: "Upload failed: ${e.toString()}"
      );
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

  // Platform-specific success message
  void _showPlatformSuccessMessage(String message) {
    if (_isDesktop) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final isDesktop = _isDesktop;

    // Platform-specific dimensions
    final containerWidth = isDesktop ? width * 0.5.clamp(400, 700) : width * 0.93;
    final topPadding = isDesktop ? height * 0.02 : height * 0.05;
    final containerPadding = isDesktop ? width * 0.025 : width * 0.04;
    final elementSpacing = isDesktop ? height * 0.015 : height * 0.015;
    final infoSpacing = isDesktop ? height * 0.008 : height * 0.01;
    final buttonSpacing = isDesktop ? height * 0.02 : height * 0.025;

    // Platform-specific font sizes
    final titleFontSize = isDesktop ? width * 0.038 : width * 0.04;
    final buttonFontSize = isDesktop ? width * 0.038 : width * 0.04;
    final infoFontSize = isDesktop ? width * 0.033 : width * 0.035;
    final smallFontSize = isDesktop ? width * 0.031 : width * 0.033;
    final noteFontSize = isDesktop ? width * 0.032 : width * 0.034;

    return Scaffold(
      backgroundColor: MyColors.lightGray,
      body: Column(
        children: [
          CustomAppHeader(
            title: "${"upload_cars_title".tr()}",
            onBack: () {
              Navigator.pop(context);
            },
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                top: topPadding,
                bottom: isDesktop ? 20 : 0,
              ),
              child: Center(
                child: Container(
                  width: containerWidth,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(isDesktop ? 12 : 12),
                    boxShadow: isDesktop ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      )
                    ] : null,
                  ),
                  padding: EdgeInsets.all(containerPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Upload Label
                      Text(
                        "📄 Upload Excel/CSV File *",
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF444444),
                        ),
                      ),
                      SizedBox(height: elementSpacing),

                      // File Upload Section - Platform specific
                      if (isDesktop)
                        _buildDesktopFileUpload(width, height, infoFontSize)
                      else
                        _buildMobileFileUpload(width, height, infoFontSize),

                      SizedBox(height: elementSpacing * 0.7),

                      // Supported formats text
                      Text(
                        "Supported formats: Excel (.xlsx, .xls) and CSV (.csv)",
                        style: TextStyle(
                          fontSize: smallFontSize,
                          color: const Color(0xFF666666),
                        ),
                      ),

                      SizedBox(height: elementSpacing),

                      // Info container
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(containerPadding * 0.9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F5FF),
                          borderRadius: BorderRadius.circular(8),
                          border: isDesktop ? Border.all(
                            color: Colors.blue[100]!,
                            width: 1,
                          ) : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "File Format Instructions:",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: isDesktop ? width * 0.036 : width * 0.038,
                                color: const Color(0xFF444444),
                              ),
                            ),
                            SizedBox(height: infoSpacing),

                            _buildInfoLine("• Column A: Registration Number *", width, height, isDesktop),
                            _buildInfoLine("• Column B: GPS Location", width, height, isDesktop),
                            _buildInfoLine("• Column C: Searched At (optional, uses timestamp)", width, height, isDesktop),
                            _buildInfoLine("• Column D: Location Details (optional)", width, height, isDesktop),

                            SizedBox(height: infoSpacing * 1.5),

                            Text(
                              "Note: Your Agent ID will be automatically linked to the uploaded records.",
                              style: TextStyle(
                                fontSize: noteFontSize,
                                fontStyle: FontStyle.italic,
                                color: const Color(0xFF444444),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: buttonSpacing),

                      // Upload Button - Platform specific
                      if (isDesktop)
                        _buildDesktopUploadButton(width, height, buttonFontSize)
                      else
                        _buildMobileUploadButton(width, height, buttonFontSize),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Desktop File Upload Section
  Widget _buildDesktopFileUpload(double width, double height, double fontSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // File chooser button with hover effect
        MouseRegion(
          cursor: _isUploading ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _isUploading ? null : _chooseFile,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: _isUploading ? Colors.grey[300] : Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isUploading ? Colors.grey[400]! : Colors.blue[200]!,
                  width: 1.5,
                ),
              ),
              padding: EdgeInsets.symmetric(
                vertical: height * 0.018,
                horizontal: width * 0.03,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: width * 0.045,
                    color: _isUploading ? Colors.grey : Colors.blue[700],
                  ),
                  SizedBox(width: width * 0.015),
                  Text(
                    "Choose File",
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      color: _isUploading ? Colors.grey : Colors.blue[700],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: height * 0.015),

        // Selected file display
        if (_selectedFile != null)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(width * 0.02),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  size: width * 0.04,
                  color: Colors.green[700],
                ),
                SizedBox(width: width * 0.015),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fileName,
                        style: TextStyle(
                          fontSize: fontSize * 0.95,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF444444),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: height * 0.003),
                      Text(
                        "${(_selectedFile!.size / 1024).toStringAsFixed(2)} KB",
                        style: TextStyle(
                          fontSize: fontSize * 0.85,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: width * 0.04),
                  color: Colors.grey[600],
                  onPressed: _isUploading ? null : () {
                    setState(() {
                      _fileName = "No file chosen";
                      _filePath = null;
                      _selectedFile = null;
                    });
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Mobile File Upload Section
  Widget _buildMobileFileUpload(double width, double height, double fontSize) {
    return Row(
      children: [
        GestureDetector(
          onTap: _isUploading ? null : _chooseFile,
          child: Container(
            decoration: BoxDecoration(
              color: _isUploading
                  ? const Color(0xFFB0B0B0)
                  : const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(6),
            ),
            padding: EdgeInsets.symmetric(
              vertical: height * 0.012,
              horizontal: width * 0.03,
            ),
            child: Text(
              "Choose file",
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                color: _isUploading ? Colors.grey : Colors.black,
              ),
            ),
          ),
        ),
        SizedBox(width: width * 0.03),
        Expanded(
          child: Text(
            _fileName,
            style: TextStyle(
              fontSize: fontSize,
              color: _selectedFile != null
                  ? const Color(0xFF444444)
                  : const Color(0xFF888888),
              fontWeight: _selectedFile != null
                  ? FontWeight.w500
                  : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // Desktop Upload Button
  Widget _buildDesktopUploadButton(double width, double height, double fontSize) {
    return MouseRegion(
      cursor: _isUploading ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _isUploading ? null : callUploadCarRecordAPI,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: _isUploading
                ? Colors.red[300]
                : Colors.red[600],
            borderRadius: BorderRadius.circular(8),
            boxShadow: _isUploading
                ? null
                : [
              BoxShadow(
                color: Colors.red.withOpacity(0.3),
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(vertical: height * 0.018),
          child: Center(
            child: _isUploading
                ? SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_upload,
                  color: Colors.white,
                  size: width * 0.045,
                ),
                SizedBox(width: width * 0.015),
                Text(
                  "⬆ ${"upload_records".tr()}",
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
    );
  }

  // Mobile Upload Button
  Widget _buildMobileUploadButton(double width, double height, double fontSize) {
    return GestureDetector(
      onTap: _isUploading ? null : callUploadCarRecordAPI,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _isUploading
              ? const Color(0xFFE57373)
              : const Color(0xFFD32F2F),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: EdgeInsets.symmetric(vertical: height * 0.015),
        child: Center(
          child: _isUploading
              ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
              : Text(
            "⬆ ${"upload_records".tr()}",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: fontSize,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoLine(String text, double width, double height, bool isDesktop) {
    return Padding(
      padding: EdgeInsets.only(bottom: isDesktop ? height * 0.004 : height * 0.005),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "•",
            style: TextStyle(
              fontSize: isDesktop ? width * 0.032 : width * 0.035,
            ),
          ),
          SizedBox(width: width * 0.015),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: isDesktop ? width * 0.032 : width * 0.035,
              ),
            ),
          ),
        ],
      ),
    );
  }
}