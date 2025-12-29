import 'dart:convert';

import 'offline_search_db.dart';
import '../services/repository.dart';
import '../services/end_points.dart';

class OfflineSearchSyncService {
  static Future<void> sync({
    required String adminId,
    required String deviceToken,
  }) async {
    final records = await OfflineSearchDB.getAll();

    if (records.isEmpty) return;

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
    print("skofflinerePay${payload}");

    final response = await Repository.postApiRawService(
      EndPoints.uploadCarSearches,
      payload,
    );

    final parsed = response is String ? jsonDecode(response) : response;

    if (parsed["success"] == true || parsed["status"] == true) {
      await OfflineSearchDB.clear();
    }
  }
}
