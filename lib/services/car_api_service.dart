import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:repo_agent_application/services/repository.dart';
import '../data/prefernces.dart';
import '../database/car_action_dao.dart';
import '../database/car_master_dao.dart';
import '../models/car_action_model.dart';
import '../models/car_master_model.dart';
import '../utils/util_class.dart';
import 'end_points.dart';
import '../database/car_master_dao.dart';

class CarApiService {
  // ✅ 1. GET ALL CARS (Initial load and sync)
  // ✅ 1. GET ALL CARS (Initial load and sync) - UPDATED TO POST
  static Future<List<CarMasterModel>> fetchAllCarsOld() async {
    try {
      // Get user details for authentication
      final dataStr = await Preferences.getUserDetails();
      if (dataStr == null || dataStr.isEmpty) {
        print("❌ No user details found for fetching cars");
        throw Exception("No user details found");
      }

      final data = jsonDecode(dataStr);
      final deviceId = data["device_token"]?.toString() ?? "";
      final userId = data["admin_id"]?.toString() ?? "";

      if (deviceId.isEmpty || userId.isEmpty) {
        print("❌ Missing device_token or admin_id");
        throw Exception("Missing authentication data");
      }

      // Check internet connection
      final internet = await UtilClass.checkInternet();
      if (!internet) {
        print("❌ No internet connection");
        throw Exception("No internet connection");
      }

      print("🌐 Fetching all cars from backend...");

      // Use Repository.postApiRawService instead of http.get
      final response = await Repository.postApiRawService(
        EndPoints.getAllCarsMainData, // This should be your cars endpoint
        {'device_token': deviceId, 'admin_id': userId},
      );

      // Handle response
      dynamic parsed;
      if (response is String) {
        parsed = json.decode(response);
      } else {
        parsed = response;
      }
      print("sk fetchAllCars ${parsed}");

      // Check if response is successful
      if (parsed is Map && parsed["status"] == true) {
        // Safely access nested data
        final data = parsed["data"];
        if (data != null && data is Map) {
          final cars = data["cars"];

          if (cars != null && cars is List) {
            print("📥 Fetched ${cars.length} cars from backend");

            return cars
                .where((e) => e is Map)
                .map((e) => CarMasterModel.fromJson(e as Map<String, dynamic>))
                .toList();
          } else {
            print("❌ 'cars' is not a List or is null");
            throw Exception("Invalid cars data format");
          }
        } else {
          print("❌ 'data' is null or not a Map");
          throw Exception("Invalid response format");
        }
      } else {
        final errorMsg = parsed is Map
            ? parsed["message"]?.toString()
            : "Failed to load cars";
        print("❌ API returned error: $errorMsg");
        throw Exception(errorMsg ?? "Failed to load cars");
      }
    } catch (e, stackTrace) {
      print("❌ Error in fetchAllCars: $e");
      print("❌ Stack trace: $stackTrace");
      rethrow;
    }
  }

  // ✅ 2. SYNC CARS TO BACKEND (POST local updates)
  static Future<bool> syncCars(List<Map<String, dynamic>> cars) async {
    try {
      // ✅ GET LAST SYNC TIME FROM DB
      final lastSyncTime = await CarMasterDao.getLastSyncTime();
      // Get user details for authentication
      final dataStr = await Preferences.getUserDetails();
      if (dataStr == null || dataStr.isEmpty) {
        print("❌ No user details found for sync");
        return false;
      }

      final data = jsonDecode(dataStr);
      final deviceId = data["device_token"]?.toString() ?? "";
      final userId = data["admin_id"]?.toString() ?? "";

      if (deviceId.isEmpty || userId.isEmpty) {
        print("❌ Missing device_token or admin_id for sync");
        return false;
      }

      // Check internet connection
      final internet = await UtilClass.checkInternet();
      if (!internet) {
        print("❌ No internet connection for sync");
        return false;
      }

      // ✅ FILTER & FORMAT CARS FOR API
      final List<Map<String, dynamic>> formattedCars = cars.map((car) {
        return {
          "car_id": car["backend_car_id"] ?? car["car_id"], // IMPORTANT
          "status": car["status"],
          if (car["gps_location"] != null) "gps_location": car["gps_location"],
          if (car["location_details"] != null)
            "location_details": car["location_details"],
          if (car["notes"] != null) "notes": car["notes"],
          if (car["photo"] != null) "photo": car["photo"],
          "updated_at": car["updated_at"],
        };
      }).toList();

      if (formattedCars.isEmpty) {
        print("⚠️ No valid cars to sync");
        return true;
      }

      print("🔄 Syncing ${cars.length} cars to backend...");

      // Prepare sync payload
      final payload = {
        'device_token': deviceId,
        'admin_id': userId,
        "last_sync": lastSyncTime == "Never" ? null : lastSyncTime,
        'cars': formattedCars,
      };
      print("masterPendings ${payload}");

      // Call your existing Repository method
      final response = await Repository.postApiRawService(
        EndPoints.syncMasterCarsEndpoint, // You'll need to add this endpoint
        payload,
      );

      // Handle response
      dynamic parsed;
      if (response is String) {
        parsed = json.decode(response);
      } else {
        parsed = response;
      }

      // Check if sync was successful
      if (parsed is Map && parsed["status"] == true) {
        print("✅ Successfully synced ${cars.length} master cars");
        return true;
      } else {
        final errorMsg = parsed is Map
            ? parsed["message"]?.toString()
            : "Sync failed";
        print("❌ Car sync failed: $errorMsg");
        return false;
      }
    } catch (e) {
      print("❌ Error syncing cars: $e");
      return false;
    }
  }

  // ✅ 3. SYNC ACTIONS TO BACKEND (POST local actions)
  static Future<bool> syncActions(List<Map<String, dynamic>> actions) async {
    try {
      // Get user details for authentication
      final dataStr = await Preferences.getUserDetails();
      if (dataStr == null || dataStr.isEmpty) {
        print("❌ No user details found for sync");
        return false;
      }

      final List<Map<String, dynamic>> formattedActions = actions.map((action) {
        return {
          "reg_no": action["reg_no"],
          "car_id": action["backend_car_id"] ?? action["car_id"], // IMPORTANT
          "car_make": action["car_make"],
          "status": action["status"],
          if (action["photo"] != null) "photo": action["photo"],
          "found": action["found"] ?? 0,
          if (action["gps_location"] != null)
            "gps_location": action["gps_location"],
          if (action["location_details"] != null)
            "location_details": action["location_details"],
          if (action["notes"] != null) "notes": action["notes"],
          "searchedd_at":
              action["searchedd_at"]

        };
      }).toList();

      if (formattedActions.isEmpty) {
        print("⚠️ No valid actions to sync");
        return true;
      }

      final data = jsonDecode(dataStr);
      final deviceId = data["device_token"]?.toString() ?? "";
      final userId = data["admin_id"]?.toString() ?? "";

      if (deviceId.isEmpty || userId.isEmpty) {
        print("❌ Missing device_token or admin_id for sync");
        return false;
      }

      // Check internet connection
      final internet = await UtilClass.checkInternet();
      if (!internet) {
        print("❌ No internet connection for sync");
        return false;
      }

      print("🔄 Syncing ${actions.length} actions to backend...");

      // Prepare sync payload
      final payload = {
        'device_token': deviceId,
        'admin_id': userId,
        // 'sync_time': DateTime.now().toIso8601String(),
        'searches': formattedActions,
      };

      // Call your existing Repository method
      final response = await Repository.postApiRawService(
        EndPoints.syncActionsEndpoint, // You'll need to add this endpoint
        payload,
      );

      print("888 offline searches ${response}");
      // Handle response
      dynamic parsed;
      if (response is String) {
        parsed = json.decode(response);
      } else {
        parsed = response;
      }

      // Check if sync was successful
      if (parsed is Map && parsed["success"] == true) {
        print("Successfully synced ${actions.length} car actions");
        return true;
      } else {
        final errorMsg = parsed is Map
            ? parsed["message"]?.toString()
            : "Sync failed";
        print("❌ Action sync failed: $errorMsg");
        return false;
      }
    } catch (e) {
      print("❌ Error syncing actions: $e");
      return false;
    }
  }

  // ✅ 4. EXISTING METHOD - GET AGENT SEARCH MASTER DATA
  static Future<void> getAgentSearchMasterData() async {
    try {
      // Get user details
      final dataStr = await Preferences.getUserDetails();
      if (dataStr == null || dataStr.isEmpty) {
        print("❌ No user details found");
        return;
      }

      final data = jsonDecode(dataStr);
      final deviceId = data["device_token"]?.toString() ?? "";
      final userId = data["admin_id"]?.toString() ?? "";

      if (deviceId.isEmpty || userId.isEmpty) {
        print("❌ Missing device_token or admin_id");
        return;
      }

      // Check internet connection
      final internet = await UtilClass.checkInternet();
      if (!internet) {
        print("❌ No internet connection");
        return;
      }

      print("🌐 Fetching agent search master data...");

      try {
        final value = await Repository.postApiRawService(
          EndPoints.getAgentSearchMainData,
          {'device_token': deviceId, 'admin_id': userId},
        );

        UtilClass.hideProgress();

        // Handle different response formats
        dynamic parsed;
        if (value is String) {
          parsed = json.decode(value);
        } else {
          parsed = value;
        }

        // Check if parsed is Map and has status
        if (parsed is Map && parsed["status"] == true) {
          // Safely access nested data
          final data = parsed["data"];
          if (data != null && data is Map) {
            final cars = data["cars"];

            if (cars != null && cars is List) {
              final actions = cars
                  .where((e) => e is Map)
                  .map(
                    (e) => CarActionModel.fromJson(e as Map<String, dynamic>),
                  )
                  .toList();

              await CarActionDao.insertBackendActions(
                actions,
              ); // Updated method name
              print("✅ ${actions.length} search actions saved locally");
            } else {
              print("❌ 'cars' is not a List or is null");
            }
          } else {
            print("❌ 'data' is null or not a Map");
          }
        } else {
          final errorMsg = parsed is Map
              ? parsed["message"]?.toString()
              : "Failed to load matched cars";
          print("❌ API returned error: ${errorMsg ?? 'Unknown error'}");
        }
      } catch (e, stackTrace) {
        UtilClass.hideProgress();
        print("❌ API Error: $e");
        print("❌ Stack trace: $stackTrace");
        rethrow;
      }
    } catch (e) {
      UtilClass.hideProgress();
      print("❌ Error in getAgentSearchMasterData: $e");
      rethrow;
    }
  }

  // ✅ 5. HELPER METHOD - Get authentication token
  static Future<Map<String, String>> _getAuthHeaders() async {
    final dataStr = await Preferences.getUserDetails();
    if (dataStr == null || dataStr.isEmpty) {
      return {};
    }

    final data = jsonDecode(dataStr);
    final deviceId = data["device_token"]?.toString() ?? "";
    final userId = data["admin_id"]?.toString() ?? "";

    return {'device_token': deviceId, 'admin_id': userId};
  }

  // ✅ 6. COMPATIBILITY METHOD - Keep your existing code working
  static Future<List<CarMasterModel>> fetchCars() async {
    // Call the new method for compatibility
    return await fetchAllCarsOld();
  }

  //get new  and update master data cars

  // Add this method to CarApiService class

  // ✅ FETCH NEW AND UPDATED CARS FROM BACKEND
  static Future<List<CarMasterModel>> fetchNewAndUpdatedMasterCars({
    String? lastCreatedAt,
    String? lastUpdatedAt,
  }) async {
    try {
      // Get user details for authentication
      final dataStr = await Preferences.getUserDetails();
      if (dataStr == null || dataStr.isEmpty) {
        print("❌ No user details found");
        throw Exception("No user details found");
      }

      final data = jsonDecode(dataStr);
      final deviceId = data["device_token"]?.toString() ?? "";
      final userId = data["admin_id"]?.toString() ?? "";

      if (deviceId.isEmpty || userId.isEmpty) {
        print("❌ Missing device_token or admin_id");
        throw Exception("Missing authentication data");
      }

      // Check internet connection
      final internet = await UtilClass.checkInternet();
      if (!internet) {
        print("❌ No internet connection");
        throw Exception("No internet connection");
      }

      print("🌐 Fetching new/updated cars from backend...");

      // Prepare request body
      final Map<String, dynamic> requestBody = {
        'device_token': deviceId,
        'admin_id': userId,
      };

      // ✅ CRITICAL FIX: Determine which endpoint to call
      final bool isInitialFetch = (lastCreatedAt == null || lastCreatedAt.isEmpty) &&
          (lastUpdatedAt == null || lastUpdatedAt.isEmpty);

      String endpoint;

      if (isInitialFetch) {
        // 🆕 FIRST-TIME SYNC: Fetch all records
        endpoint = EndPoints.getAllCarsMainData; // Your "get all cars" endpoint
        print("🔄 Initial fetch: Getting ALL cars (no timestamps available)");
      } else {
        // 🔄 SUBSEQUENT SYNC: Fetch only new/updated records
        endpoint = EndPoints.getMasterUpdateCars; // Your "get updates" endpoint

        // Add timestamps to the request
        if (lastCreatedAt != null && lastCreatedAt.isNotEmpty) {
          requestBody['created_at'] = lastCreatedAt;
        }
        if (lastUpdatedAt != null && lastUpdatedAt.isNotEmpty) {
          requestBody['updated_at'] = lastUpdatedAt;
        }
        print("📤 Fetching updates since: created_at=$lastCreatedAt, updated_at=$lastUpdatedAt");
      }

      print("📤 Request body: $requestBody");

      // Use Repository.postApiRawService
      final response = await Repository.postApiRawService(
        endpoint, // Your API endpoint
        requestBody,
      );

      // Handle response
      dynamic parsed;
      if (response is String) {
        parsed = json.decode(response);
      } else {
        parsed = response;
      }

      print(
        "📥 API Response: ${parsed is Map ? parsed["status"] : "Invalid format"}",
      );

      // Check if response is successful
      if (parsed is Map && parsed["status"] == true) {
        final responseData = parsed["data"];

        if (responseData != null && responseData is Map) {
          final cars = responseData["cars"];

          if (cars != null && cars is List) {
            print("✅ Fetched ${cars.length} new/updated cars");

            return cars
                .where((e) => e is Map)
                .map((e) => CarMasterModel.fromJson(e as Map<String, dynamic>))
                .toList();
          } else {
            print("⚠️ No cars in response or cars is not a List");
            return [];
          }
        } else {
          print("⚠️ No data in response");
          return [];
        }
      } else {
        final errorMsg = parsed is Map
            ? parsed["message"]?.toString()
            : "Failed to fetch updates";
        print("❌ API error: $errorMsg");
        throw Exception(errorMsg ?? "Failed to fetch updates");
      }
    } catch (e, stackTrace) {
      print("❌ Error fetching new/updated cars: $e");
      print("❌ Stack trace: $stackTrace");
      rethrow;
    }
  }

  // ✅ FETCH ALL CARS (For initial sync)
  static Future<List<CarMasterModel>> fetchAllCars() async {
    // This is your existing method, keep it as is
    // Used for first-time sync only
    return await fetchNewAndUpdatedMasterCars(
      lastCreatedAt: null,
      lastUpdatedAt: null,
    );
  }
}
