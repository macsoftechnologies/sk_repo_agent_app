import 'dart:convert';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:repo_agent_application/services/repository.dart';


import '../database/car_action_dao.dart';

import 'end_points.dart';

class CarActionSyncService {
  static Timer? _timer;

  /// START AUTO SYNC
  static void startAutoSync({
    required int adminId,
    required String deviceToken,
  }) {
    // Run immediately
    syncNow(adminId: adminId, deviceToken: deviceToken);

    // Then every 30 minutes
    _timer = Timer.periodic(
      const Duration(minutes: 30),
          (_) => syncNow(adminId: adminId, deviceToken: deviceToken),
    );
  }

  /// STOP AUTO SYNC (optional)
  static void stopAutoSync() {
    _timer?.cancel();
  }

  /// MAIN SYNC LOGIC
  static Future<void> syncNow({
    required int adminId,
    required String deviceToken,
  }) async {
    print("🔄 Sync started...");

    // 1️⃣ Check Internet
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      print("❌ No internet. Sync skipped.");
      return;
    }

    // 2️⃣ Get pending records
    final records = await CarActionDao.getPendingSyncActions();

    if (records.isEmpty) {
      print("✅ No pending records to sync");
      return;
    }

    // 3️⃣ Prepare payload
    final payload = {
      "admin_id": adminId,
      "device_token": deviceToken,
      "searches": records.map((e) {
        return {
          "reg_no": e["reg_no"],
          "location_details": e["location_details"],
          "notes": e["notes"],
          "car_id": e["car_id"],
          "car_make": e["car_make"],
          "status": e["status"],
          "photo": e["photo"],
          "found": e["found"],
          "searched_at": e["searched_at"],
        };
      }).toList()
    };

    print("📤 Sync Payload: $payload");

    try {
      // 4️⃣ POST to backend
      final response = await Repository.postApiRawService(
        EndPoints.uploadCarSearches,
        payload,
      );

      final parsed = response is String ? jsonDecode(response) : response;

      // 5️⃣ SUCCESS → Mark as synced
      if (parsed["success"] == true || parsed["status"] == true) {
        await CarActionDao.markActionsAsSynced(records);
        print("🎉 Sync success (${records.length} records)");
      } else {
        await _handleFailedSync(records);
      }
    } catch (e) {
      print("❌ Sync error: $e");
      await _handleFailedSync(records);
    }
  }

  /// HANDLE FAILED SYNC
  static Future<void> _handleFailedSync(List<Map<String, dynamic>> records) async {
    final ids = records.map((e) => e["id"] as int).toList();
    await CarActionDao.incrementSyncAttempts(ids);
    print("⚠️ Sync failed. Attempts increased.");
  }
}
