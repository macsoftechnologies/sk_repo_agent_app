import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:repo_agent_application/utils/my_colors.dart';
import '../../components/custom_app_header.dart';
import '../../components/success_popup.dart';
import '../../components/upper_case_converter.dart';
import '../../database/car_action_dao.dart';
import '../../database/car_master_dao.dart';
import '../../helpers/offline_search_db.dart';
import '../../models/car_search_model.dart';
import '../../models/last_searches_model.dart';
import '../../models/offline_search.dart';
import '../../services/repository.dart';
import '../../services/end_points.dart';
import '../../data/prefernces.dart';
import '../../utils/config.dart';
import '../../utils/util_class.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:typed_data';

final AudioPlayer _audioPlayer = AudioPlayer();

class SearchCarsScreen extends StatefulWidget {
  const SearchCarsScreen({Key? key}) : super(key: key);

  @override
  State<SearchCarsScreen> createState() => _SearchCarsScreenState();
}

class _SearchCarsScreenState extends State<SearchCarsScreen> {
  String userName = "";
  String deviceId = "";
  String userId = "";

  TextEditingController regController = TextEditingController();
  TextEditingController locationController = TextEditingController();
  TextEditingController remarkController = TextEditingController();
  String? _locationDetails;
  String? _regNo;
  String? _lastSearchRegNo;

  bool showSearchResults = false;
  bool showLastSearches = false;
  bool isLoading = false;
  bool isLoadingLastSearches = false;

  String? latitude;
  String? longitude;
  bool isManualLocation = false;

  CarData? carData;
  String apiMessage = "";
  List<CarData> searchResults = [];
  List<LastSearchItem> lastThreeSearches = [];

  List<OfflineSearch> offlineSearches = [];
  bool isLoadingOfflineSearches = false;
  bool showOfflineSearches = true;

  // Platform detection
  bool get _isDesktop => kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  void initState() {
    super.initState();
    locationController.addListener(_onLocationChanged);
    loadUserData();
    lastTenSearchedCarsLocal();
    //loadOfflineSearches();
    // Initialize database with delay to ensure other async calls complete
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(Duration(milliseconds: 500));
      await OfflineSearchDB.database; // Initialize DB
      loadOfflineSearches();
    });
    _getCurrentLocation();

  }

  Future<void> loadOfflineSearches() async {
    setState(() => isLoadingOfflineSearches = true);

    try {
      // Test database connection first
      final isConnected = await OfflineSearchDB.testConnection();
      if (!isConnected) {
        print('Database not connected');
        return;
      }

      final records = await OfflineSearchDB.getAll();
      print('Loaded ${records.length} offline searches');

      offlineSearches = records.map((e) {
        return OfflineSearch(
          regNo: e['reg_no']?.toString() ?? 'Unknown',
          searchedAt: e['searched_at']?.toString() ?? DateTime.now().toIso8601String(),
        );
      }).toList();
    } catch (e) {
      print('Error loading offline searches: $e');
      offlineSearches = [];
    } finally {
      setState(() => isLoadingOfflineSearches = false);
    }
  }

  void loadUserData() async {
    final dataStr = await Preferences.getUserDetails();
    if (dataStr != null && dataStr.isNotEmpty) {
      try {
        final data = jsonDecode(dataStr);
        setState(() {
          userId = data["admin_id"]?.toString() ?? "";
          deviceId = data["device_token"]?.toString() ?? "";
          userName = data["name"] ?? "";
        });
      } catch (e) {
        print("Error loading user data: $e");
      }
    }
  }

  @override
  void dispose() {
    locationController.removeListener(_onLocationChanged);
    super.dispose();
  }

  void _onLocationChanged() {
    final currentText = locationController.text;
    if (currentText.isEmpty || _locationDetails != currentText) {
      isManualLocation = true;
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

  Future<void> playBellSound() async {
    await _audioPlayer.play(AssetSource('sounds/bell_sound.mp3'));
  }

  void _sendLocationToBackend() async {
    final internet = await UtilClass.checkInternet();
    if (!internet) {
      _showPlatformAlertDialog(context: context, message: Config.kNoInternet);
      setState(() {
        locationController.text = "No internet connection";
      });
      return;
    }

    if (latitude == null || longitude == null) {
      setState(() {
        locationController.text = "Location not available";
      });
      return;
    }

    try {
      final value = await Repository.postApiRawService(
        EndPoints.getLocationApi,
        {
          "latitude": latitude!,
          "longitude": longitude!,
          "device_token": deviceId,
        },
      );

      dynamic parsed;
      if (value is String) {
        parsed = json.decode(value);
      } else {
        parsed = value;
      }

      if (parsed["success"] == true) {
        final locationDetails = parsed["data"]["location_details"] as String?;
        setState(() {
          if (locationDetails != null && locationDetails.isNotEmpty) {
            locationController.text = locationDetails;
            _locationDetails = locationDetails;
            isManualLocation = false;
          } else {
            locationController.text = "Location not available";
          }
        });
      } else {
        setState(() {
          locationController.text = "Failed to get location details";
        });
      }
    } catch (e) {
      print("Error in _sendLocationToBackend: $e");
      setState(() {
        locationController.text = "Error fetching location";
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enable location services")),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Location permission denied")),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Location permission permanently denied")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      latitude = position.latitude.toString();
      longitude = position.longitude.toString();

      setState(() {
        locationController.text = "Fetching address...";
        isManualLocation = false;
      });

      _sendLocationToBackend();
    } catch (e) {
      print("Error getting location: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error getting location: $e")),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _clearLocation() {
    setState(() {
      locationController.clear();
      _locationDetails = null;
      latitude = null;
      longitude = null;
      isManualLocation = false;
    });
  }

  bool _validateInputs() {
    if (regController.text.trim().isEmpty) {
      _showPlatformAlertDialog(
        context: context,
        message: "Please enter Registration Number",
      );
      return false;
    }

    if (locationController.text.trim().isEmpty) {
      _showPlatformAlertDialog(
        context: context,
        message: "Please enter Location Details",
      );
      return false;
    }

    return true;
  }

  void searchCarAPI() async {
    if (!_validateInputs()) return;

    final location = locationController.text.trim();
    final regNo = regController.text.trim();
    final notes = remarkController.text.trim();

    final internet = await UtilClass.checkInternet();

    // 📴 OFFLINE
    if (!internet) {
      await OfflineSearchDB.insert({
        "reg_no": regNo,
        "location_details": location,
        "notes": notes.isNotEmpty ? notes : "No remarks",
        "car_id": null,
        "car_make": null,
        "status": null,
        "photo": null,
        "found": 0,
        "searched_at": DateTime.now().toString(),
      });

      // Test if data was saved
      final count = await OfflineSearchDB.getCount();
      print('Offline searches count after save: $count');

      regController.clear();
      remarkController.clear();
      await loadOfflineSearches();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No internet. Search saved offline."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final value = await Repository.postApiRawService(EndPoints.searchCarsApi, {
        "admin_id": userId.toString(),
        "device_token": deviceId.toString(),
        "reg_no": regNo,
        "location_details": location,
        "notes": notes.isNotEmpty ? notes : "No remarks",
      });
      print("carsSearchvalues reg ${regNo}  lac ${location} notes ${notes}");
      print("carsSearchvalues1 dev ${deviceId.toString()}  use ${userId.toString()} notes ${notes}");

      print("carsSearchRes${value}");

      final parsed = value is String ? json.decode(value) : value;

      if (parsed["success"] == true || parsed["status"] == true) {
        _lastSearchRegNo = regController.text.trim();
        playBellSound();

        final carResponse = CarSearchResponse.fromJson(parsed);

        setState(() {
          carData = carResponse.data;
          apiMessage = carResponse.message;
          showSearchResults = true;

          if (!searchResults.any((car) => car.regNo == carResponse.data!.regNo)) {

            searchResults.insert(0, carResponse.data!);
          }
        });

        await lastTenSearchedCarsLocal();
        SuccessPopup.show(
          context,
          message: "Car found successfully",
        );


        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text(carResponse.message),
        //     backgroundColor: Colors.green,
        //   ),
        // );
      } else {
        _lastSearchRegNo = regController.text.trim();
        await lastTenSearchedCarsLocal();
        setState(() {
          carData = null;
          apiMessage = parsed["message"];
        });
      }
    } catch (e) {
      _showPlatformAlertDialog(context: context, message: e.toString());
    } finally {
      setState(() => isLoading = false);
      regController.clear();
      remarkController.clear();
    }
  }


  // 🔄 NEW METHOD: Refresh car data after update
  Future<void> _refreshCarData(String regNo) async {
    try {
      // 1. Fetch updated car from database
      final updatedCar = await CarMasterDao.findCarByRegNo(regNo);

      if (updatedCar != null) {
        // 2. Create updated CarData object
        final updatedCarData = CarData(
          batchNumber: updatedCar['batch_number'] ?? '',
          regNo: updatedCar['reg_no'],
          carMake: updatedCar['car_make'] ?? '',
          carModel: updatedCar['car_modal'] ?? '',
          status: updatedCar['status'] ?? '',
          gpsLocation: updatedCar['gps_location'] ?? '',
          locationDetails: updatedCar['location_details'] ?? '',
          //photo: updatedCar['photo'] ?? '',
          createdAt: updatedCar['created_at'] ?? '',
          updatedAt: updatedCar['updated_at'] ?? '',
         // assignedAgentName: updatedCar['assigned_agent_name'] ?? '',
          //assignedAgentId: updatedCar['assigned_agent_id'] ?? 0,
        );

        // 3. Update UI state
        setState(() {
          // Update main car data
          carData = updatedCarData;

          // Update in search results list
          final index = searchResults.indexWhere((c) => c.regNo == regNo);
          if (index != -1) {
            //searchResults[index] = updatedCarData;
            searchResults.clear();
            searchResults.insert(0, updatedCarData);
          }


          apiMessage = "Car updated successfully";
        });

        print("🔄 Car data refreshed for: $regNo");

        // 4. Show success message
      } else {
        print("❌ Could not find updated car: $regNo");
      }
    } catch (e) {
      print("❌ Error refreshing car data: $e");
    }
  }

  Future<void> searchCarLocal() async {
    print("🔍 Searching car...");
    if (!_validateInputs()) return;

    final regNo = regController.text.trim();
    final location = locationController.text.trim();
    final notes = remarkController.text.trim();

    setState(() => isLoading = true);

    try {
      // 🔍 1. Search in car_master
      final car = await CarMasterDao.findCarByRegNo(regNo);
      print("carFountData:${car}");

      if (car != null) {
        // 🛎️ Bell sound for found car
        playBellSound();
        _lastSearchRegNo = regController.text.trim();
        _locationDetails=locationController.text.trim();

        // ✅ CAR FOUND
        final carData1 = CarData(
          batchNumber: car['batch_number'] ?? '',
          regNo: car['reg_no'],
          carMake: car['car_make'] ?? '',
          carModel: car['car_modal'] ?? '',
          status: car['status'] ?? '',
          gpsLocation: car['gps_location'] ?? '',
          locationDetails:car['locationDetails'] ?? '',
          createdAt: car['created_at'] ?? '',
          updatedAt: car['updated_at'] ?? '',
        );

        // 📝 INSERT NEW SEARCH RECORD (FOUND)
        await CarActionDao.insertSearchAction(
          regNo: car['reg_no'],
          agentId: int.parse(userId),
          found: 1,
          carMake: car['car_make'],
          carModal: car['car_modal'],
          status: car['status'],
          gpsLocation: car['gps_location'],
          locationDetails:car['locationDetails'] ?? '',
          notes: notes.isNotEmpty ? notes : "No remarks",
          carId: car['car_id'],
        );


        setState(() {
          searchResults.clear();
          carData = carData1;
          apiMessage = "Car found successfully";
          showSearchResults = true;
        });

        // Add to search results list
        if (!searchResults.any((c) => c.regNo == carData1.regNo)) {
          searchResults.clear();
          searchResults.insert(0, carData1);
        }



        SuccessPopup.show(context, message: "✅ Car found successfully!");

        // Show search count for this car
        final history = await CarActionDao.getCarSearchHistory(regNo);
        print("📊 This car has been searched ${history.length} times");

      } else {
        _lastSearchRegNo = regController.text.trim();
        _locationDetails=locationController.text.trim();
        // ❌ CAR NOT FOUND

        // 📝 INSERT NEW SEARCH RECORD (NOT FOUND)
        await CarActionDao.insertSearchAction(
          regNo: regNo,
          agentId: int.parse(userId),
          found: 0,
          locationDetails: location,
          notes: notes.isNotEmpty ? notes : "No remarks",
        );

        setState(() {
          carData = null;
          apiMessage = "Car not found in database";
        });


      }

      // 🔄 Refresh last searches display
      await lastTenSearchedCarsLocal();

      // Show search statistics
      final stats = await CarActionDao.getSearchStats();
      print("📊 Total searches: ${stats['total_searches']}, Found: ${stats['found']}, Not Found: ${stats['not_found']}");

    } catch (e) {
      print("❌ Search error: $e");
      _showPlatformAlertDialog(context: context, message: "Error: ${e.toString()}");
    } finally {
      setState(() => isLoading = false);
      regController.clear();
      remarkController.clear();
    }
  }


  bool _validateInputsForRemarks() {
    final notes = remarkController.text.trim();
    if (notes.isEmpty) {
      _showPlatformAlertDialog(
        context: context,
        message: 'Enter remarks to add to the car',
      );
      return false;
    }
    if (_lastSearchRegNo == null && regController.text.trim().isEmpty) {
      _showPlatformAlertDialog(
        context: context,
        message: 'Registration number is required',
      );
      return false;
    }

    if (_locationDetails == null || _locationDetails!.isEmpty) {
      _showPlatformAlertDialog(
        context: context,
        message: 'Location details are required',
      );
      return false;
    }

    return true;
  }

  void addRemarkToCarAPI() async {
    if (!_validateInputsForRemarks()) {
      return;
    }

    String regNo = (_lastSearchRegNo != null && _lastSearchRegNo!.trim().isNotEmpty)
        ? _lastSearchRegNo!.trim()
        : regController.text.trim();
    final notes = remarkController.text.trim();

    final internet = await UtilClass.checkInternet();
    if (!internet) {
      _showPlatformAlertDialog(context: context, message: Config.kNoInternet);
      return;
    }

    setState(() {
      isLoading = true;
    });

    final body = {
      "admin_id": userId.toString(),
      "device_token": deviceId.toString(),
      "reg_no": regNo,
      "location_details": _locationDetails,
      "notes": notes.isNotEmpty ? notes : "No remarks",
    };

    print("tttBodyRema ${body}");
    try {
      final value = await Repository.postApiRawService(EndPoints.searchCarsApi, body);
      print("remarksRegRes ${value}");

      dynamic parsed;
      if (value is String) {
        parsed = json.decode(value);
      } else {
        parsed = value;
      }

      if (parsed["success"] == true || parsed["status"] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Remark Added To Car Successfully"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        regController.clear();
        remarkController.clear();
      } else {
        final errorMessage = parsed["message"] ?? "Car not found";
        _showPlatformAlertDialog(context: context, message: errorMessage);

        setState(() {
          carData = null;
          apiMessage = errorMessage;
        });
      }
    } catch (e) {
      print("Error in searchCarAPI: $e");
      _showPlatformAlertDialog(context: context, message: e.toString());
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }
  void addRemarkToCarLocal() async {
    if (!_validateInputsForRemarks()) {
      return;
    }

    String regNo = (_lastSearchRegNo != null && _lastSearchRegNo!.trim().isNotEmpty)
        ? _lastSearchRegNo!.trim()
        : regController.text.trim();
    final notes = remarkController.text.trim();

    final internet = await UtilClass.checkInternet();
    if (!internet) {
      _showPlatformAlertDialog(context: context, message: Config.kNoInternet);
      return;
    }

    setState(() {
      isLoading = true;
    });

    final body = {
      "admin_id": userId.toString(),
      "device_token": deviceId.toString(),
      "reg_no": regNo,
      "location_details": _locationDetails,
      "notes": notes.isNotEmpty ? notes : "No remarks",
    };

    print("tttBodyRema ${body}");
    try {

      final result = await CarActionDao.updateLatestLocationAndNotesByRegNo(
        regNo: regNo,
        locationDetails: _locationDetails!,
        notes: notes,
      );

      if (result['success']) {
        print("✅ ${result['message']}");
        print("Rows affected:add remarks ${result['rows_affected']}");
        await _refreshCarData(regNo);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.green,
          ),
        );
        regController.clear();
        remarkController.clear();
      } else {
        print("❌ ${result['message']}");

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }

    } catch (e) {
      print("Error in searchCarAPI: $e");
      _showPlatformAlertDialog(context: context, message: e.toString());
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> lastTenSearchedCarsLocal() async {
    setState(() {
      isLoadingLastSearches = true;
    });

    try {
      final data = await CarActionDao.getLast10SearchedCars();

      final response = {
        "success": true,
        "message": "Last searches retrieved successfully",
        "data": data.map((e) => {
          "reg_no": e["reg_no"],
          "found": e["found"].toString(), // keep API compatibility
        }).toList(),
      };

      print("Local Last Searches Response: $response");


      final parsedResponse = LastSearchesResponse.fromJson(response);
      print("lastsearchCount ${parsedResponse.data.length}");

      setState(() {
        lastThreeSearches = parsedResponse.data;
      });
    } catch (e) {
      print("Error fetching last searches locally: $e");

      setState(() {
        lastThreeSearches = [];
      });
    } finally {
      setState(() {
        isLoadingLastSearches = false;
      });
    }
  }


  // Future<void> lastThreeSearchedCarsAPI() async {
  //   if (deviceId.isEmpty) {
  //     await Future.delayed(Duration(milliseconds: 100));
  //     if (deviceId.isEmpty) return;
  //   }
  //
  //   final internet = await UtilClass.checkInternet();
  //   if (!internet) {
  //     print("No internet for last 3 searches API");
  //     return;
  //   }
  //
  //   setState(() {
  //     isLoadingLastSearches = true;
  //   });
  //
  //   try {
  //     final value = await Repository.postApiRawService(
  //       EndPoints.last3SearchedCarsApi,
  //       {'device_token': deviceId.toString(),
  //         'admin_id': userId.toString()},
  //     );
  //
  //     UtilClass.hideProgress();
  //     print("3Res ${value}");
  //
  //     dynamic parsed;
  //     if (value is String) {
  //       parsed = json.decode(value);
  //     } else {
  //       parsed = value;
  //     }
  //
  //     if (parsed["success"] == true) {
  //       final lastSearchesResponse = LastSearchesResponse.fromJson(parsed);
  //       setState(() {
  //         lastThreeSearches = lastSearchesResponse.data;
  //         print("Last 3 searches loaded: ${lastThreeSearches.length} items");
  //       });
  //     } else {
  //       print("Failed to load last 3 searches: ${parsed["message"]}");
  //       setState(() {
  //         lastThreeSearches = [];
  //       });
  //     }
  //   } catch (e) {
  //     UtilClass.hideProgress();
  //     print("Error in lastTenSearchedCarsLocal: $e");
  //     setState(() {
  //       lastThreeSearches = [];
  //     });
  //   } finally {
  //     setState(() {
  //       isLoadingLastSearches = false;
  //     });
  //   }
  // }

  void _onLastSearchTap(String regNo) {
    // No change needed for Windows
  }

  void _updateCarStatus(CarData car) async {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => UpdateCarPopup(
        carData: car,
        onSave: (updatedValues) {
          debugPrint("Updated values: $updatedValues");
          _callUpdateCarLocally(car, updatedValues);
        },
      ),
    );
  }

  Future<File?> compressImage(File file) async {
    final dir = await getTemporaryDirectory();
    final targetPath = p.join(
      dir.path,
      "${DateTime.now().millisecondsSinceEpoch}.jpg",
    );

    try {
      final compressedBytes = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        quality: 50,
        format: CompressFormat.jpeg,
      );

      if (compressedBytes == null) return null;

      final compressedFile = File(targetPath)
        ..writeAsBytesSync(compressedBytes);
      print("Original size: ${file.lengthSync()} bytes");
      print("Compressed size: ${compressedFile.lengthSync()} bytes");
      return compressedFile;
    } catch (e) {
      print("Compression error: $e");
      return null;
    }
  }

  void _callUpdateCarAPI(
      CarData car,
      Map<String, dynamic> updatedValues,
      ) async {

    final internet = await UtilClass.checkInternet();
    if (!internet) {
      _showPlatformAlertDialog(context: context, message: Config.kNoInternet);
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      String? base64Image;
      final imagePath = updatedValues["uploadPhoto"]?.toString();
      if (imagePath != null &&
          imagePath.isNotEmpty &&
          imagePath != "No file selected") {
        try {
          final imageFile = File(imagePath);
          File originalFile = File(imagePath);

          if (await originalFile.exists()) {
            File? compressed = await compressImage(originalFile);
            final fileToUpload = compressed ?? originalFile;

            List<int> imageBytes = await fileToUpload.readAsBytes();
            base64Image = base64Encode(imageBytes);
            print("Base64 size after compression: ${base64Image.length} chars");
          }
        } catch (e) {
          print("Error converting image to base64: $e");
        }
      } else {
        print("No image to upload or empty path");
      }

      String currentDate = DateTime.now().toString();
      Map<String, dynamic> params = {
        "admin_id": userId.toString(),
        "device_token": deviceId.toString(),
        "reg_no": car.regNo,
        "status": updatedValues["status"] ?? "Unverified",
        "location_details":
        updatedValues["locationDetails"] ?? car.locationDetails ?? "",
        "gps_location": updatedValues["gpsLocation"] ?? car.gpsLocation,
        "notes": updatedValues["notes"] ?? "",
        "assigned_agent_id":userId,
        "assigned_agent_name":userName,
        "updated_at": currentDate,
        "updated_by":userId
      };

      if (base64Image != null && base64Image.isNotEmpty) {
        params["photo"] = base64Image.toString();
        print("Photo888${base64Image}");
      } else {
        params["photo"] = "";
        print("No photo to send, using empty string");
      }

      print("Sending update request with params: $params");

      final value = await Repository.postApiRawService(
        EndPoints.updateCarsApi,
        params,
      );

      dynamic parsed;
      if (value is String) {
        parsed = json.decode(value);
      } else {
        parsed = value;
      }

      print("Update API response44: $parsed");

      if (parsed["success"] == true || parsed["status"] == true) {
        final updatedCar = CarData(
          batchNumber: car.batchNumber,
          regNo: car.regNo,
          carMake: car.carMake,
          carModel: car.carModel,
          status: updatedValues["status"] ?? "Unverified",
          gpsLocation: updatedValues["gpsLocation"] ?? car.gpsLocation,
          locationDetails:
          updatedValues["locationDetails"] ?? car.locationDetails,
          createdAt: car.createdAt,
          updatedAt: DateTime.now().toString(),
        );

        setState(() {
          final index = searchResults.indexWhere((c) => c.regNo == car.regNo);
          if (index != -1) {
            searchResults[index] = updatedCar;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(parsed["message"] ?? "Car updated successfully"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        _showPlatformAlertDialog(
          context: context,
          message: parsed["message"] ?? "Update failed",
        );
      }
    } catch (e) {
      print("Error updating car: $e");
      _showPlatformAlertDialog(context: context, message: e.toString());
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }


  void _callUpdateCarLocally(
      CarData car,
      Map<String, dynamic> updatedValues,
      ) async {

    setState(() {
      isLoading = true;
    });
    try {
      String? base64Image;
      final imagePath = updatedValues["uploadPhoto"]?.toString();
      if (imagePath != null &&
          imagePath.isNotEmpty &&
          imagePath != "No file selected") {
        try {
          final imageFile = File(imagePath);
          File originalFile = File(imagePath);
          if (await originalFile.exists()) {
            File? compressed = await compressImage(originalFile);
            final fileToUpload = compressed ?? originalFile;

            List<int> imageBytes = await fileToUpload.readAsBytes();
            base64Image = base64Encode(imageBytes);
            print("Base64 size after compression: ${base64Image.length} chars");
          }
        } catch (e) {
          print("Error converting image to base64: $e");
        }
      } else {
        print("No image to upload or empty path");
      }
      String currentDate = DateTime.now().toString();
      Map<String, dynamic> params = {
        "admin_id": userId.toString(),
        "device_token": deviceId.toString(),
        "reg_no": car.regNo,
        "status": updatedValues["status"] ?? "Unverified",
        "location_details":
        updatedValues["locationDetails"] ?? car.locationDetails ?? "",
        "gps_location": updatedValues["gpsLocation"] ?? car.gpsLocation,
        "notes": updatedValues["notes"] ?? "",
        "assigned_agent_id": userId,
        "assigned_agent_name": userName,
        "updated_at": currentDate,
        "updated_by": userId
      };
      if (base64Image != null && base64Image.isNotEmpty) {
        params["photo"] = base64Image.toString();
        print("Photo888${base64Image}");
      } else {
        params["photo"] = "";
        print("No photo to send, using empty string");
      }
      print("Sending update request with params: $params");
      int agentId = int.parse(userId);
      // 🔹 LOCAL DB UPDATE FIRST
      final actionRows = await CarActionDao.updateActionByRegNo(
        regNo: car.regNo,
        status: "found",
        found: 1,
        gpsLocation: updatedValues["gpsLocation"] ?? car.gpsLocation,
        locationDetails:
        updatedValues["locationDetails"] ?? car.locationDetails ?? "",
        notes: updatedValues["notes"] ?? "",

      );

    final masterRows =await CarMasterDao.updateCarByRegNo(
        regNo: car.regNo,
        status: updatedValues["status"] ?? "Unverified",
        gpsLocation: updatedValues["gpsLocation"] ?? car.gpsLocation,
        locationDetails:
        updatedValues["locationDetails"] ?? car.locationDetails ?? "",
        notes: updatedValues["notes"] ?? "",
        photo: base64Image,
        updatedBy: agentId,
        agentId: agentId,
        agentName: userName,
      );
      if (actionRows > 0 && masterRows > 0) {
        print("✅ Local DB update SUCCESS");
        // 🔄 REFRESH: Fetch updated car data
        await _refreshCarData(car.regNo);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Car updated locally"),
            backgroundColor: Colors.green,
          ),
        );

      } else {
        print("❌ Local DB update FAILED");

        _showPlatformAlertDialog(
          context: context,
          message: "Local update failed. Record not found.",
        );
      }

      setState(() {
        isLoading = false;
      });

    }catch (e){
      print("Error updating car: $e");
      _showPlatformAlertDialog(context: context, message: e.toString());
    }



  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final isDesktop = _isDesktop;

    // Platform-specific dimensions
    final double horizontalPadding = isDesktop ? width * 0.05 : width * 0.04;
    final double verticalSpacing = isDesktop ? height * 0.02 : height * 0.01;
    final double cardSpacing = isDesktop ? height * 0.02 : height * 0.02;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: Column(
        children: [
          CustomAppHeader(
            title: '${"search_cars_title".tr()}',
            onBack: () => Navigator.pop(context),
          ),
          SizedBox(height: verticalSpacing),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main Search Section
                    if (isDesktop)
                      _buildDesktopSearchSection(width, height, cardSpacing)
                    else
                      _buildMobileSearchCard(width, height),

                    SizedBox(height: cardSpacing),

                    // Search Results Section
                    if (searchResults.isNotEmpty || showSearchResults)
                      isDesktop
                          ? _buildDesktopSearchResults(width, height, cardSpacing)
                          : _buildMobileSearchResultsCard(width, height),

                    SizedBox(height: cardSpacing),

                    // Last Three Searches
                    if (lastThreeSearches.isNotEmpty)
                      isDesktop
                          ? _buildDesktopLastSearches(width, height, cardSpacing)
                          : _buildMobileLastThreeSearchesCard(width, height),

                    SizedBox(height: cardSpacing),

                    // Offline Searches
                    // if (offlineSearches.isNotEmpty)
                    //   isDesktop
                    //       ? _buildDesktopOfflineSearches(width, height, cardSpacing)
                    //       : _buildMobileOfflineSearchedCarsCard(width, height),
                    //
                    // SizedBox(height: height * 0.03),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================== DESKTOP UI COMPONENTS ===========================

  Widget _buildDesktopSearchSection(double width, double height, double spacing) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
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
              Text(
                '🔍 ${"search_by_reg".tr()}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF333333),
                ),
              ),

            ],
          ),
          SizedBox(height: 20),

          // Location Field with Auto-Detect
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '📍 ${"location_details".tr()} *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF444444),
                ),
              ),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: locationController,
                        readOnly: false,
                        decoration: InputDecoration(
                          hintText: "Enter location or use auto-detect",
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.all(16),
                          border: InputBorder.none,
                          suffixIcon: locationController.text.isNotEmpty
                              ? IconButton(
                            icon: Icon(Icons.clear, size: 20),
                            onPressed: _clearLocation,
                          )
                              : null,
                        ),
                        onChanged: (value) {
                          if (value.isNotEmpty && _locationDetails != value) {
                            setState(() {
                              isManualLocation = true;
                            });
                          }
                        },
                      ),
                    ),
                    Container(
                      width: 120,
                      margin: EdgeInsets.only(right: 8),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: isLoading ? null : _getCurrentLocation,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: MyColors.greenBackground,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  isLoading
                                      ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                      : Icon(Icons.my_location, size: 18, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    "Auto-detect",
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
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

          SizedBox(height: 16),

          // Registration Number
          _buildDesktopInputField(
            "${'reg_no'.tr()} *",
            "Enter registration number (e.g., MH12AB1234)",
            regController,
            true, // isUpperCase
          ),

          SizedBox(height: 16),

          // Search Button
          MouseRegion(
            cursor: isLoading ? SystemMouseCursors.wait : SystemMouseCursors.click,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isLoading ? Colors.blue[300] : MyColors.greenBackground,
                borderRadius: BorderRadius.circular(10),
                boxShadow: isLoading ? null : [
                  BoxShadow(
                    color: MyColors.greenBackground.withOpacity(0.3),
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isLoading ? null : searchCarLocal,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isLoading)
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        else
                          Icon(Icons.search, color: Colors.white, size: 20),
                        SizedBox(width: 12),
                        Text(
                          "Search Car",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SizedBox(height: 20),

          // Remarks Section
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(

                  " 📝 ${'remarks'.tr()} *",

                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF444444),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: remarkController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: "Enter additional notes or remarks...",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    contentPadding: EdgeInsets.all(14),
                  ),
                ),
                SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.orange[600],
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.2),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: addRemarkToCarLocal,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add, size: 18, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  "${'add'.tr()} ",
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopSearchResults(double width, double height, double spacing) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
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
              Text(
                " 📋  ${'search_results'.tr()} ",

                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF333333),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: searchResults.isEmpty ? Colors.grey[100] : Colors.green[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: searchResults.isEmpty ? Colors.grey[300]! : Colors.green[100]!,
                  ),
                ),
                child: Text(
                  "${searchResults.length} ${searchResults.length == 1 ? 'Result' : 'Results'}",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: searchResults.isEmpty ? Colors.grey[600] : Colors.green[600],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          if (searchResults.isNotEmpty)
            Column(
              children: searchResults.map((car) {
                final isVerified = car.status == "Verified";
                return Container(
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isVerified ? Colors.green[100]! : Colors.blue[100]!,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    leading: Container(
                      width: 6,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isVerified ? Colors.green : MyColors.appThemeDark,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    title: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.car_rental, size: 20, color: MyColors.appThemeLight),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                car.regNo,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF333333),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "${car.carMake}",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: const Color(0xFF666666),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isVerified ? Colors.green[50] : Colors.orange[50],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isVerified ? Colors.green[100]! : Colors.orange[100]!,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isVerified ? Icons.verified : Icons.pending,
                                size: 14,
                                color: isVerified ? Colors.green[600] : Colors.orange[600],
                              ),
                              SizedBox(width: 6),
                              // Text(
                              //   car.status,
                              //   style: TextStyle(
                              //     fontSize: 14,
                              //     fontWeight: FontWeight.w500,
                              //     color: isVerified ? Colors.green[600] : Colors.orange[600],
                              //   ),
                              // ),
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
                          children: [
                            _buildDesktopDetailRow("${'batch_no'.tr()}:", car.batchNumber),
                            //SizedBox(height: 12),
                            //_buildDesktopDetailRow("${'gps_location'.tr()}:", car.gpsLocation),
                            SizedBox(height: 12),
                            _buildDesktopDetailRow("${'cmodel'.tr()}:", car.carMake),// "${car.carMake}",
                            SizedBox(height: 12),
                            _buildDesktopDetailRow("${'outstanding'.tr()}:", car.createdAt),
                           // SizedBox(height: 12),
                           // _buildDesktopDetailRow("${'updated_at'.tr()}:", car.updatedAt),
                           /// SizedBox(height: 12),
                            //_buildDesktopDetailRow("${'location_details'.tr()}:", car.locationDetails ?? "Not available"),
                            SizedBox(height: 20),
                            if (car.status == "Unverified")
                              Align(
                                alignment: Alignment.centerRight,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.blue[600],
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.blue.withOpacity(0.2),
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => _updateCarStatus(car),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.edit, size: 18, color: Colors.white),
                                              SizedBox(width: 8),
                                              Text(
                                                '${'update'.tr()}',
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
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            )
          else
            Container(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 60, color: Colors.grey[300]),
                  SizedBox(height: 16),
                  Text(
                    "No search results yet",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Search for a car to see results here",
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
    );
  }

  Widget _buildDesktopLastSearches(double width, double height, double spacing) {


    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
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
              Text(
                " 🕐 ${'last_three_searched_cars'.tr()}",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF333333),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.purple[100]!),
                ),
                child: Text(
                  "Recent ${lastThreeSearches.length}",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.purple[600],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          if (isLoadingLastSearches)
            Container(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: CircularProgressIndicator(
                  color: MyColors.greenBackground,
                ),
              ),
            )
          else if (lastThreeSearches.isNotEmpty)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: lastThreeSearches.asMap().entries.map((entry) {
                int index = entry.key;
                LastSearchItem item = entry.value;


                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    width: 220,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _onLastSearchTap( item.regNo,),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: MyColors.appThemeLight1,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    "${index + 1}",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                               " ${'reg_no'.tr()}",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      item.regNo,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: item.isFound ? Colors.green : Colors.red,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            )
          else
            Container(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.history_toggle_off, size: 50, color: Colors.grey[300]),
                    SizedBox(height: 12),
                    Text(
                      "No recent searches",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
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

  Widget _buildDesktopOfflineSearches(double width, double height, double spacing) {
    String _formatDate(String dateString) {
      try {
        final dateTime = DateTime.parse(dateString);
        return DateFormat('dd-MM-yyyy HH:mm').format(dateTime);
      } catch (e) {
        return dateString;
      }
    }

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
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
              Text(
                '📱 ${'offline_searched_cars'.tr()}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF333333),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange[100]!),
                ),
                child: Text(
                  "${offlineSearches.length} Pending",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.orange[600],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          if (isLoadingOfflineSearches)
            Container(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: CircularProgressIndicator(
                  color: MyColors.greenBackground,
                ),
              ),
            )
          else if (offlineSearches.isNotEmpty)
            DataTable(
              columns: [
                DataColumn(label: Text("#")),
                DataColumn(label: Text("${'reg_num'.tr()}")),
                DataColumn(label: Text("${'searched_on'.tr()}")),
                DataColumn(label: Text("${'status'.tr()}")),
              ],
              rows: offlineSearches.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return DataRow(
                  cells: [
                    DataCell(Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Center(
                        child: Text(
                          "${index + 1}",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )),
                    DataCell(Text(item.regNo,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: MyColors.greyTextColor,
                        ))),
                    DataCell(Text(_formatDate(item.searchedAt),
                        style: TextStyle(color: Colors.grey[600]))),
                    DataCell(
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange[100]!),
                        ),
                        child: Text(
                          "Offline",
                          style: TextStyle(
                            color: Colors.orange[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            )
          else
            Container(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.cloud_off, size: 50, color: Colors.grey[300]),
                    SizedBox(height: 12),
                    Text(
                      "No offline searches",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "All searches are synced with server",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
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

  Widget _buildDesktopInputField(
      String label,
      String hint,
      TextEditingController controller,
      bool isUpperCase,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF444444),
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: TextField(
            controller: controller,
            textCapitalization: isUpperCase ? TextCapitalization.characters : TextCapitalization.none,
            inputFormatters: isUpperCase ? [UpperCaseTextFormatter()] : [],
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.all(16),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopDetailRow(String label, String value) {
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
              fontSize: 15,
            ),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Text(
            value.isNotEmpty ? value : "Not available",
            style: TextStyle(
              fontSize: 17,
              color: const Color(0xFF333333),
            ),
          ),
        ),
      ],
    );
  }

  // =========================== MOBILE UI COMPONENTS (ORIGINAL) ===========================

  Widget _buildMobileSearchCard(double width, double height) {
    return Container(
      width: width,
      padding: EdgeInsets.all(width * 0.04),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${"search_by_reg".tr()}',
            style: TextStyle(
              fontSize: width * 0.06,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: height * 0.02),

          // Location field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${"location_details".tr()}*',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (isManualLocation)
                    Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Text(
                        "(Manually entered)",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: locationController,
                      readOnly: false,
                      decoration: InputDecoration(
                        hintText: "Enter location or click button to auto-fill",
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.all(14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        suffixIcon: locationController.text.isNotEmpty
                            ? IconButton(
                          icon: Icon(Icons.clear, size: 20),
                          onPressed: _clearLocation,
                        )
                            : null,
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty && _locationDetails != value) {
                          setState(() {
                            isManualLocation = true;
                          });
                        }
                      },
                    ),
                  ),
                  SizedBox(width: 8),
                  Column(
                    children: [
                      ElevatedButton(
                        onPressed: isLoading ? null : _getCurrentLocation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MyColors.greenBackground,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.all(12),
                        ),
                        child: isLoading
                            ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : Icon(Icons.my_location, color: Colors.white),
                      ),
                      SizedBox(height: 4),
                      if (latitude != null && longitude != null)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "Location ready",
                            style: TextStyle(fontSize: 10, color: Colors.green),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 4),
              Text(
                "Tip: You can type your address manually OR click the location button to auto-fill",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),

          _inputFieldUpperCase(
            "${'reg_no'.tr()} *",
            "Enter registration number",
            regController,
          ),

          SizedBox(height: height * 0.015),
          _searchButton(width, height),
          SizedBox(height: height * 0.02),
          _inputField(
            "${'remarks'.tr()}",
            "Enter any remarks or notes",
            remarkController,
          ),
          SizedBox(height: height * 0.01),

          Align(
            alignment: Alignment.bottomRight,
            child: ElevatedButton(
              onPressed: addRemarkToCarLocal,
              style: ElevatedButton.styleFrom(
                backgroundColor: MyColors.greenBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: width * 0.05,
                  vertical: height * 0.012,
                ),
              ),
              child: Text(
                "+ ${'add'.tr()}",
                style: TextStyle(fontSize: width * 0.04, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileSearchResultsCard(double width, double height) {
    return Container(
      padding: EdgeInsets.all(width * 0.04),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            '${"search_results".tr()}',
            searchResults.isNotEmpty
                ? "${searchResults.length} Results"
                : "No Results",
            showSearchResults,
                () => setState(() => showSearchResults = !showSearchResults),
          ),
          if (showSearchResults && searchResults.isNotEmpty)
            Column(
              children: searchResults.map((car) {
                return Container(
                  margin: EdgeInsets.only(top: width * 0.03),
                  padding: EdgeInsets.all(width * 0.04),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border(
                      left: BorderSide(
                        color: car.status == "Verified"
                            ? Colors.green
                            : MyColors.appThemeLight1,
                        width: 5,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 4),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row('${"batch_no".tr()}:', car.batchNumber, width),
                      _row('${"registration_no".tr()}:', car.regNo, width),
                      _row('${"car_make".tr()}:', car.carMake, width),
                     // _row('${"car_model".tr()}:', car.carModel, width),
                     // _row('${"gps_location".tr()}:', car.gpsLocation, width),
                      _row('${"created".tr()}:', car.createdAt, width),
                     // _row('${"updated_at".tr()}:', car.updatedAt, width),
                     // _statusRow(car.status, width),
                     //  _row(
                     //    '${"location_details".tr()}:',
                     //    car.locationDetails ?? "Not available",
                     //    width,
                     //  ),
                      SizedBox(height: height * 0.012),
                      if (car.status == "Unverified")
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            onPressed: () => _updateCarStatus(car),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: EdgeInsets.symmetric(
                                vertical: height * 0.01,
                                horizontal: width * 0.05,
                              ),
                            ),
                            child: isLoading
                                ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : Text(
                              '${"update".tr()}',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          if (showSearchResults && searchResults.isEmpty)
            Container(
              padding: EdgeInsets.all(width * 0.04),
              child: Center(
                child: Text(
                  apiMessage.isNotEmpty ? apiMessage : "No search results yet",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileLastThreeSearchesCard(double width, double height) {
    return Container(
      padding: EdgeInsets.all(width * 0.04),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            '${"last_three_searched_cars".tr()}',
            lastThreeSearches.isNotEmpty
                ? "${lastThreeSearches.length} Cars"
                : "No Searches",
            showLastSearches,
                () => setState(() => showLastSearches = !showLastSearches),
          ),
          if (showLastSearches)
            isLoadingLastSearches
                ? Container(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(
                  color: MyColors.greenBackground,
                ),
              ),
            )
                : lastThreeSearches.isNotEmpty
                ? Column(
              children: lastThreeSearches.asMap().entries.map((entry) {
                int index = entry.key;
                LastSearchItem item = entry.value;

                return InkWell(
                  onTap: () => _onLastSearchTap(item.regNo),
                  child: Container(
                    margin: EdgeInsets.only(top: width * 0.03),
                    padding: EdgeInsets.all(width * 0.04),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border(
                        left: BorderSide(
                          color: MyColors.appThemeLight1,
                          width: 5,
                        ),
                      ),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 2),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: MyColors.appThemeLight1,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              "${index + 1}",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: width * 0.04),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${"reg_no".tr()}:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                item.regNo,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: item.isFound ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.grey,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            )
                : Container(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  "No recent searches found",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileOfflineSearchedCarsCard(double width, double height) {
    String _formatDate(String dateString) {
      try {
        final dateTime = DateTime.parse(dateString);
        return DateFormat('dd-MM-yyyy HH:mm').format(dateTime);
      } catch (e) {
        return dateString;
      }
    }

    if (offlineSearches.isEmpty && !isLoadingOfflineSearches) {
      return SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.only(top: height * 0.02),
      padding: EdgeInsets.all(width * 0.04),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            '${"offline_searched_cars".tr()}',
            offlineSearches.isNotEmpty
                ? "${offlineSearches.length} Cars"
                : "No Searches",
            showOfflineSearches,
                () => setState(() => showOfflineSearches = !showOfflineSearches),
          ),
          if (showOfflineSearches)
            isLoadingOfflineSearches
                ? Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(
                  color: MyColors.greenBackground,
                ),
              ),
            )
                : offlineSearches.isNotEmpty
                ? Column(
              children: offlineSearches.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return Container(
                  margin: EdgeInsets.only(top: width * 0.03),
                  padding: EdgeInsets.all(width * 0.04),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border(
                      left: BorderSide(color: Colors.orange, width: 5),
                    ),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 2),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            "${index + 1}",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: width * 0.04),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${"reg_num".tr()}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              item.regNo,
                              style: TextStyle(
                                fontSize: 16,
                                color: MyColors.greenBackground,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              "${"searched_on".tr()}: ${_formatDate(item.searchedAt)}",
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            )
                : Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  "No offline searches found",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // =========================== HELPER METHODS (MOBILE) ===========================

  Widget _inputField(
      String label,
      String hint,
      TextEditingController controller,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 12),
        Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }

  Widget _inputFieldUpperCase(
      String label,
      String hint,
      TextEditingController controller,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 12),
        Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 6),
        TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [UpperCaseTextFormatter()],
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: MyColors.lightpeachColor,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
    );
  }

  Widget _row(String key, String value, double width) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: width * 0.32,
            child: Text(
              key,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : "Not available",
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: MyColors.greyTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusRow(String status, double width) {
    return Row(
      children: [
        SizedBox(
          width: width * 0.32,
          child: Text(
            '${"status".tr()}:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Text(
          status,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: status == "Verified" ? MyColors.greenBackground : Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _cardHeader(
      String title,
      String subtitle,
      bool isOpen,
      VoidCallback toggle,
      ) {
    return InkWell(
      onTap: toggle,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 16,
              color: MyColors.greenBackground,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(width: 6),
          Icon(isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
        ],
      ),
    );
  }

  Widget _searchButton(double width, double height) {
    return ElevatedButton(
      onPressed: isLoading ? null : searchCarLocal,
      style: ElevatedButton.styleFrom(
        backgroundColor: MyColors.greenBackground,
        minimumSize: Size(width, height * 0.06),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else
            Icon(Icons.search, color: Colors.white),
          SizedBox(width: isLoading ? 0 : 8),
          isLoading
              ? SizedBox(width: 8)
              : Text(
            "Search",
            style: TextStyle(
              fontSize: width * 0.045,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// Keep your existing UpdateCarPopup class here (not modified)

// ------------------------------------------------------
// POPUP WIDGET - Add this at the bottom of your file
// ------------------------------------------------------


class UpdateCarPopup extends StatefulWidget {
  final CarData carData;
  final Function(Map<String, dynamic>) onSave;

  const UpdateCarPopup({Key? key, required this.carData, required this.onSave})
      : super(key: key);

  @override
  State<UpdateCarPopup> createState() => _UpdateCarPopupState();
}

class _UpdateCarPopupState extends State<UpdateCarPopup> {
  final formKey = GlobalKey<FormState>();

  late TextEditingController regController;
  late TextEditingController gpsController;
  late TextEditingController locationDetailsController;
  late TextEditingController carDetailsController;
  late TextEditingController notesController;

  late String selectedStatus;
  File? imageFile;
  bool isGettingLocation = false;

  String? latitude;
  String? longitude;

  // Platform detection
  bool get _isDesktop => kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  void initState() {
    super.initState();
    regController = TextEditingController(text: widget.carData.regNo);
    gpsController = TextEditingController(
      text: widget.carData.gpsLocation ?? "",
    );
    locationDetailsController = TextEditingController(
      text: widget.carData.locationDetails ?? "",
    );
    carDetailsController = TextEditingController(
      text: "${widget.carData.carMake} ${widget.carData.carModel}".trim(),
    );
    notesController = TextEditingController();

    selectedStatus = "Others";
    _getCurrentLocation();
  }

  @override
  void dispose() {
    regController.dispose();
    gpsController.dispose();
    locationDetailsController.dispose();
    carDetailsController.dispose();
    notesController.dispose();
    super.dispose();
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

  // Gallery pick
  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        imageFile = File(picked.path);
      });
    }
  }

  // Camera pick
  Future<void> takePhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked != null) {
      setState(() {
        imageFile = File(picked.path);
      });
    }
  }

  // Location sending to backend
  void _sendLocationToBackend() async {
    final internet = await UtilClass.checkInternet();
    final deviceId = await Preferences.getDeviceId();

    if (!internet) {
      _showPlatformAlertDialog(context: context, message: Config.kNoInternet);
      setState(() {
        gpsController.text = "No internet connection";
      });
      return;
    }

    if (latitude == null || longitude == null) {
      setState(() {
        gpsController.text = "Location not available";
      });
      return;
    }

    try {
      final value = await Repository.postApiRawService(
        EndPoints.getLocationApi,
        {
          "latitude": latitude!,
          "longitude": longitude!,
          "device_token": deviceId,
        },
      );

      dynamic parsed;
      if (value is String) {
        parsed = json.decode(value);
      } else {
        parsed = value;
      }

      if (parsed["success"] == true) {
        final locationDetails = parsed["data"]["location_details"] as String?;

        setState(() {
          gpsController.text =
          (locationDetails != null && locationDetails.isNotEmpty)
              ? locationDetails
              : "Location not available";
        });
      } else {
        setState(() {
          gpsController.text = "Failed to get location details";
        });
      }
    } catch (e) {
      print("Error in _sendLocationToBackend: $e");
      setState(() {
        gpsController.text = "Error fetching location";
      });
    }
  }

  // Get current location
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enable location services")),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Location permission denied")),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Location permission permanently denied")),
      );
      return;
    }

    setState(() {
      isGettingLocation = true;
    });

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      latitude = position.latitude.toString();
      longitude = position.longitude.toString();

      setState(() {
        gpsController.text = "Fetching location...";
        isGettingLocation = false;
      });

      _sendLocationToBackend();
    } catch (e) {
      print("Error getting location: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error getting location: $e")),
      );
    } finally {
      setState(() {
        isGettingLocation = false;
      });
    }
  }

  // Uploaded image preview
  Widget _buildImagePreview() {
    if (imageFile == null) {
      return Container();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        _label("Uploaded Photo Preview"),
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              imageFile!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[100],
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, color: Colors.red, size: 48),
                        SizedBox(height: 12),
                        Text(
                          "Failed to load image",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[100]!),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        imageFile = null;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: Colors.red[600]),
                          SizedBox(width: 8),
                          Text(
                            "Remove Image",
                            style: TextStyle(
                              color: Colors.red[600],
                              fontWeight: FontWeight.w500,
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
      ],
    );
  }

  // Desktop UI Build
  Widget _buildDesktopUI(double width, double height) {
    return Container(
      width: width * 0.5, // Fixed width for desktop modal
      constraints: BoxConstraints(maxWidth: 600, minWidth: 500),
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "📝 ${'update_car_information'.tr()}",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF333333),
                    ),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, size: 24, color: Colors.grey[600]),
                      tooltip: "Close",
                    ),
                  ),
                ],
              ),


              SizedBox(height: 24),

              // Two-column layout for desktop
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column - Basic Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Registration Number (Disabled)
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${'reg_no'.tr()}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                widget.carData.regNo,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF333333),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 16),

                        // Car Details (Disabled)
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${'car_details'.tr()}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "${widget.carData.carMake} ${widget.carData.carModel}".trim(),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: const Color(0xFF333333),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 16),

                        // Status Selection
                        _label("${'status'.tr()} *"),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: DropdownButtonFormField<String>(
                            value: selectedStatus,
                            items: ["Sudhah Tarik", "Got Sticker", "Others"]
                                .map((e) => DropdownMenuItem(
                              value: e,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text(e),
                              ),
                            ))
                                .toList(),
                            onChanged: (v) => setState(() => selectedStatus = v!),
                            validator: (v) => v == null ? "Required" : null,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            style: TextStyle(fontSize: 14,color:Colors.black),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(width: 24),

                  // Right Column - Location & Photo
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // GPS Location with Auto-detect
                        _label("${'gps_location'.tr()} *"),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey[300]!),),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: gpsController,
                                  validator: (value) => value!.isEmpty ? "Required" : null,
                                  decoration: InputDecoration(
                                    hintText: "Enter location or use auto-detect",
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ),
                              MouseRegion(
                                cursor: isGettingLocation ? SystemMouseCursors.wait : SystemMouseCursors.click,
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: MyColors.greenBackground,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: isGettingLocation ? null : _getCurrentLocation,
                                      borderRadius: BorderRadius.circular(10),
                                      child: Center(
                                        child: isGettingLocation
                                            ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                            : Icon(Icons.my_location, size: 20, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 8),




                        // Location Details
                        _label("${'location_details'.tr()}"),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: TextFormField(
                            controller: locationDetailsController,
                            decoration: InputDecoration(
                              hintText: "Enter detailed location information",
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            maxLines: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 24),

              // Notes Section
              _label("${'additional_notes'.tr()}"),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: TextFormField(
                  controller: notesController,
                  decoration: InputDecoration(
                    hintText: "Enter any additional notes or remarks...",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  maxLines: 4,
                ),
              ),

              SizedBox(height: 24),

              // Photo Upload Section
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "📷 ${'upload_photo'.tr()}",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF444444),
                          ),
                        ),
                        if (imageFile != null)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green[100]!),
                            ),
                            child: Text(
                              "Image Selected",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 12),

                    Row(
                      children: [
                        // Gallery Button
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: pickImage,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.photo_library, size: 18, color: Colors.blue[600]),
                                      SizedBox(width: 8),
                                      Text(
                                        imageFile == null ? "Choose from Gallery" : "Change Photo",
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.blue[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(width: 12),

                        // Camera Button
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: takePhoto,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.camera_alt, size: 18, color: Colors.purple[600]),
                                      SizedBox(width: 8),
                                      Text(
                                        "Take Photo",
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.purple[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 34),
                      ],
                    ),

                    // Image Preview
                    if (imageFile != null) _buildImagePreview(),
                  ],
                ),
              ),

              SizedBox(height: 32),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            child: Row(
                              children: [
                                Icon(Icons.close, size: 18, color: Colors.grey[600]),
                                SizedBox(width: 8),
                                Text(
                                  "${'cancel'.tr()}",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(width: 16),

                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      decoration: BoxDecoration(
                        color: MyColors.greenBackground,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: MyColors.greenBackground.withOpacity(0.3),
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            if (formKey.currentState!.validate()) {
                              Map<String, dynamic> result = {
                                "registrationNumber": regController.text,
                                "gpsLocation": gpsController.text,
                                "locationDetails": locationDetailsController.text,
                                "carDetails": carDetailsController.text,
                                "status": selectedStatus,
                                "notes": notesController.text,
                                "uploadPhoto": imageFile?.path ?? "",
                              };

                              widget.onSave(result);
                              Navigator.pop(context);
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            child: Row(
                              children: [
                                Icon(Icons.save, size: 18, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  "${'save'.tr()}",
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

              SizedBox(height: 34),
            ],
          ),
        ),
      ),
    );
  }

  // Mobile UI Build (Original)
  Widget _buildMobileUI(double width, double height) {
    return Container(
      height: height * 0.90,
      width: width,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${'update_car_information'.tr()}",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, size: 24),
                  ),
                ],
              ),

              SizedBox(height: 20),

              _label("${'reg_no'.tr()}"),
              TextFormField(
                controller: regController,
                enabled: false,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),

              SizedBox(height: 15),

              _label("${'gps_location'.tr()} *"),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: gpsController,
                      validator: (value) => value!.isEmpty ? "Required" : null,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: "Enter Location",
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: isGettingLocation ? null : _getCurrentLocation,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                      backgroundColor: MyColors.greenBackground,
                    ),
                    child: isGettingLocation
                        ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : Row(
                      children: [
                        Icon(Icons.my_location, size: 18),
                        SizedBox(width: 6),
                        Text("Get"),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 15),

              _label("${'location_details'.tr()}"),
              TextFormField(
                controller: locationDetailsController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Enter location details",
                ),
                maxLines: 2,
              ),

              SizedBox(height: 15),

              _label("${'car_details'.tr()}"),
              TextFormField(
                controller: carDetailsController,
                enabled: false,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),

              SizedBox(height: 15),

              _label("${'status'.tr()} *"),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                items: ["Sudhah Tarik", "Got Sticker", "Others"]
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => selectedStatus = v!),
                validator: (v) => v == null ? "Required" : null,
                decoration: InputDecoration(border: OutlineInputBorder()),
              ),

              SizedBox(height: 15),

              _label("${'notes'.tr()}"),
              TextFormField(
                controller: notesController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Enter any notes or remarks",
                ),
                maxLines: 4,
              ),

              SizedBox(height: 20),

              _label("${'upload_photo'.tr()}"),
              if (imageFile != null) _buildImagePreview(),
              SizedBox(height: 10),

              // Gallery Button
              ElevatedButton(
                onPressed: pickImage,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_library, size: 20),
                    SizedBox(width: 8),
                    Text(imageFile == null ? "Choose File" : "Change Photo"),
                  ],
                ),
              ),

              SizedBox(height: 10),

              // Camera Button
              ElevatedButton(
                onPressed: takePhoto,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.camera_alt, size: 20),
                    SizedBox(width: 8),
                    Text("Take Photo"),
                  ],
                ),
              ),

              SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      side: BorderSide(color: Colors.grey),
                    ),
                    child: Text("${'cancel'.tr()}"),
                  ),
                  SizedBox(width: 15),
                  ElevatedButton(
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        Map<String, dynamic> result = {
                          "registrationNumber": regController.text,
                          "gpsLocation": gpsController.text,
                          "locationDetails": locationDetailsController.text,
                          "carDetails": carDetailsController.text,
                          "status": selectedStatus,
                          "notes": notesController.text,
                          "uploadPhoto": imageFile?.path ?? "",
                        };

                        widget.onSave(result);
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      backgroundColor: MyColors.greenBackground,
                    ),
                    child: Text(
                      "${'save'.tr()}",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
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

    return isDesktop ? _buildDesktopUI(width, height) : _buildMobileUI(width, height);
  }

  Widget _label(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.grey[800],
        ),
      ),
    );
  }
}
