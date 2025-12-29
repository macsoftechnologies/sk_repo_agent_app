import 'dart:convert';

import 'package:repo_agent_application/services/repository.dart';

import '../database/car_master_dao.dart';
import '../data/prefernces.dart';
import '../utils/util_class.dart';
import 'end_points.dart';

class CarMasterSyncService {
  /// 🔄 Sync updated cars to backend
  static Future<void> sync() async {
    try {
      // 1️⃣ Check internet
      final hasInternet = await UtilClass.checkInternet();
      if (!hasInternet) {
        print("❌ No internet → car master sync skipped");
        return;
      }

      // 2️⃣ Get offline updated cars
      final pendingCars = await CarMasterDao.getPendingSyncCars();
      if (pendingCars.isEmpty) {
        print("✅ No pending car updates to sync");
        return;
      }

      print("🔄 Syncing ${pendingCars.length} updated cars...");

      // 3️⃣ Get user auth data
      final dataStr = await Preferences.getUserDetails();
      if (dataStr == null) return;

      final data = jsonDecode(dataStr);
      final adminId = data["admin_id"].toString();
      final deviceToken = data["device_token"].toString();

      // 4️⃣ Prepare payload
      final payload = {
        "admin_id": adminId,
        "device_token": deviceToken,
        "cars": pendingCars.map((e) {
          return {
            "car_id": e["reg_no"],
            "status": e["status"],
            "gps_location": e["gps_location"],
            "location_details": e["location_details"],
            "notes": e["notes"],
            "photo": e["photo"],
            "assigned_agent_id": e["assigned_agent_id"],
            "assigned_agent_name": e["assigned_agent_name"],
            "updated_at": e["updated_at"],
          };
        }).toList(),
      };

      // 5️⃣ POST to backend
      final response = await Repository.postApiRawService(
        EndPoints.syncMasterCarsEndpoint,
        payload,
      );

      final parsed =
      response is String ? jsonDecode(response) : response;

      // 6️⃣ Success → mark as synced
      if (parsed["status"] == true || parsed["success"] == true) {
        final regNos = pendingCars
            .map((e) => e["reg_no"].toString())
            .toList();

        await CarMasterDao.markCarsAsSynced(regNos);

        print("Car master sync completed");
      } else {
        print("❌ Car master sync failed: ${parsed["message"]}");
      }
    } catch (e) {
      print("❌ Car master sync error: $e");
    }
  }
}
