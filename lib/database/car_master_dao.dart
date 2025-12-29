import 'package:sqflite/sqflite.dart';
import '../models/car_master_model.dart';
import 'app_database.dart';

class CarMasterDao {
  static const tableName = "car_master";

  // ✅ 1. INITIAL LOAD FROM BACKEND
  static Future<void> insertInitialCars(List<CarMasterModel> cars) async {
    final db = await AppDatabase.database;
    final batch = db.batch();

    for (var car in cars) {
      final carMap = car.toMap();
      // Mark as online and synced (from backend)
      carMap['mode'] = 'online';
      carMap['sync_status'] = 'synced';
      carMap['last_sync_time'] = DateTime.now().toIso8601String();
      carMap['backend_car_id'] = car.carId; // Server ID

      batch.insert(
        tableName,
        carMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    print("📥 Inserted ${cars.length} cars from backend");
  }

  // ✅ 2. FIND CAR BY REG NO (EXACT MATCH) - Your existing method
  static Future<Map<String, dynamic>?> findCarByRegNo(String regNo) async {
    final db = await AppDatabase.database;

    final result = await db.query(
      tableName,
      where: 'reg_no COLLATE NOCASE = ?',
      whereArgs: [regNo],
      limit: 1,
    );

    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  // ✅ 3. UPDATE CAR BY REG NO (Your existing method with sync tracking)
  static Future<int> updateCarByRegNo({
    required String regNo,
    required String status,
    required String gpsLocation,
    required String locationDetails,
    required String notes,
    required int agentId,
    required String agentName,
    String? photo,
    required int updatedBy,
  }) async {
    final db = await AppDatabase.database;

    final rowsAffected = await db.update(
      tableName,
      {
        "status": status,
        "gps_location": gpsLocation,
        "location_details": locationDetails,
        "notes": notes,
        "photo": photo ?? "",
        "updated_at": DateTime.now().toIso8601String(),
        "updated_by": updatedBy,
        "assigned_agent_id": agentId,
        "assigned_agent_name": agentName,
        "mode": "offline", // 👈 MARK AS OFFLINE CHANGE
        "sync_status": "pending", // 👈 ADD SYNC STATUS
      },
      where: "reg_no = ?",
      whereArgs: [regNo],
    );

    if (rowsAffected > 0) {
      print("✅ Updated car $regNo | Mode: offline");
    }

    return rowsAffected;
  }

  // ✅ 4. LOCAL UPDATE - Marks as offline (Alternative method)
  static Future<int> updateCarLocally({
    required String regNo,
    required String status,
    required String gpsLocation,
    required String locationDetails,
    required String notes,
    required int agentId,
    required String agentName,
    String? photo,
    required int updatedBy,
  }) async {
    // Calls the existing updateCarByRegNo method
    return await updateCarByRegNo(
      regNo: regNo,
      status: status,
      gpsLocation: gpsLocation,
      locationDetails: locationDetails,
      notes: notes,
      agentId: agentId,
      agentName: agentName,
      photo: photo,
      updatedBy: updatedBy,
    );
  }

  // ✅ 5. GET OFFLINE RECORDS FOR SYNC
  static Future<List<Map<String, dynamic>>> getPendingSyncCars() async {
    final db = await AppDatabase.database;
    return await db.query(
      tableName,
      where: 'mode = ? AND sync_status = ?',
      whereArgs: ['offline', 'pending'],
    );
  }

  // ✅ 6. UPDATE FROM BACKEND (During sync)
  static Future<void> updateFromBackend(List<CarMasterModel> backendCars) async {
    final db = await AppDatabase.database;
    final batch = db.batch();

    for (var car in backendCars) {
      final carMap = car.toMap();
      carMap['mode'] = 'online';
      carMap['sync_status'] = 'synced';
      carMap['last_sync_time'] = DateTime.now().toIso8601String();
      carMap['backend_car_id'] = car.carId;

      batch.insert(
        tableName,
        carMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    print("🔄 Updated ${backendCars.length} cars from backend");
  }

  // ✅ 7. MARK AS SYNCED (After successful POST to backend)
  static Future<void> markCarsAsSynced(List<String> regNumbers) async {
    if (regNumbers.isEmpty) return;

    final db = await AppDatabase.database;
    final placeholders = List.filled(regNumbers.length, '?').join(',');

    await db.rawUpdate('''
      UPDATE $tableName 
      SET mode = 'online', 
          sync_status = 'synced',
          last_sync_time = ?
      WHERE reg_no IN ($placeholders)
    ''', [DateTime.now().toIso8601String(), ...regNumbers]);

    print("✅ Marked ${regNumbers.length} cars as synced");
  }

  // ✅ 8. SEARCH LOCALLY (No internet)
  static Future<List<CarMasterModel>> searchCarsLocally(String query) async {
    final db = await AppDatabase.database;

    final result = await db.rawQuery('''
      SELECT * FROM $tableName 
      WHERE reg_no LIKE ? 
         OR car_make LIKE ? 
         OR car_model LIKE ?
      ORDER BY reg_no
    ''', ['%$query%', '%$query%', '%$query%']);

    return result.map((e) => CarMasterModel.fromJson(e)).toList();
  }

  // ✅ 9. GET ALL CARS (Local only)
  static Future<List<CarMasterModel>> getAllCars() async {
    final db = await AppDatabase.database;
    final result = await db.query(tableName, orderBy: 'reg_no');
    return result.map((e) => CarMasterModel.fromJson(e)).toList();
  }

  // ✅ 10. CHECK IF TABLE EMPTY
  static Future<bool> isTableEmpty() async {
    final db = await AppDatabase.database;
    final result = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $tableName'),
    );
    return result == 0;
  }

  // ✅ 11. INSERT CARS (Your existing batch insert method)
  static Future<void> insertCars(List<CarMasterModel> cars) async {
    final db = await AppDatabase.database;
    final batch = db.batch();

    for (var car in cars) {
      batch.insert(
        tableName,
        car.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  // ✅ 12. GET SYNC STATS
  static Future<Map<String, dynamic>> getSyncStats() async {
    final db = await AppDatabase.database;

    final total = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $tableName')
    ) ?? 0;

    final pending = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $tableName WHERE mode = "offline"')
    ) ?? 0;

    return {
      'total_cars': total,
      'pending_sync': pending,
      'last_sync': await getLastSyncTime(),
    };
  }

  static Future<String> getLastSyncTime() async {
    final db = await AppDatabase.database;
    final result = await db.rawQuery('''
      SELECT last_sync_time FROM $tableName 
      WHERE last_sync_time IS NOT NULL 
      ORDER BY last_sync_time DESC 
      LIMIT 1
    ''');

    return result.isNotEmpty ? result.first['last_sync_time'].toString() : 'Never';
  }

  // ✅ 13. GET CAR COUNT
  static Future<int> getCarCount() async {
    final db = await AppDatabase.database;
    final result = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $tableName'),
    );
    return result ?? 0;
  }

  // ✅ 14. DELETE CAR BY REG NO
  static Future<int> deleteCarByRegNo(String regNo) async {
    final db = await AppDatabase.database;

    final rowsAffected = await db.delete(
      tableName,
      where: 'reg_no = ?',
      whereArgs: [regNo],
    );

    if (rowsAffected > 0) {
      print("🗑️ Deleted car: $regNo");
    }

    return rowsAffected;
  }

  // ✅ 15. GET CARS BY STATUS
  static Future<List<CarMasterModel>> getCarsByStatus(String status) async {
    final db = await AppDatabase.database;

    final result = await db.query(
      tableName,
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'reg_no',
    );

    return result.map((e) => CarMasterModel.fromJson(e)).toList();
  }

  // ✅ 16. CLEAR ALL CARS (for testing)
  static Future<void> clearAllCars() async {
    final db = await AppDatabase.database;
    await db.delete(tableName);
    print("🧹 Cleared all cars master data");
  }

  //If You Need to Delete Schema Too:
  // THIS WILL DELETE TABLE STRUCTURE
  static Future<void> completelyRemoveTable() async {
    final db = await AppDatabase.database;

    // 1. Delete table (schema + data)
    await db.execute('DROP TABLE IF EXISTS $tableName');
    print("🔄 Master table deleted completely");

    // 2. Recreate fresh table
  //   await db.execute('''
  //   CREATE TABLE $tableName (
  //     car_id INTEGER PRIMARY KEY AUTOINCREMENT,
  //     reg_no TEXT NOT NULL UNIQUE,
  //     car_make TEXT,
  //     car_model TEXT,
  //     status TEXT DEFAULT 'Unverified',
  //     created_at TEXT,
  //     updated_at TEXT
  //   )
  // ''');
  //
  //   print("🔄 Table completely recreated");
  }

  //push update records,fetch latest records amd merge in table
// Add these methods to your CarMasterDao class

// ✅ GET LATEST CREATED_AT FROM LOCAL DB
  static Future<String?> getLatestCreatedAt() async {
    final db = await AppDatabase.database;
    final result = await db.rawQuery('''
    SELECT created_at FROM $tableName 
    ORDER BY datetime(created_at) DESC 
    LIMIT 1
  ''');

    if (result.isNotEmpty) {
      return result.first['created_at']?.toString();
    }
    return null;
  }

// ✅ GET LATEST UPDATED_AT FROM LOCAL DB
  static Future<String?> getLatestUpdatedAt() async {
    final db = await AppDatabase.database;
    final result = await db.rawQuery('''
    SELECT updated_at FROM $tableName 
    WHERE updated_at IS NOT NULL AND updated_at != ''
    ORDER BY datetime(updated_at) DESC 
    LIMIT 1
  ''');

    if (result.isNotEmpty) {
      return result.first['updated_at']?.toString();
    }
    return null;
  }

// ✅ SMART MERGE: Update or Insert based on backend_car_id
  static Future<void> mergeCarsFromBackend(List<CarMasterModel> backendCars) async {
    if (backendCars.isEmpty) {
      print("📭 No cars to merge");
      return;
    }

    final db = await AppDatabase.database;
    final batch = db.batch();
    int updatedCount = 0;
    int insertedCount = 0;

    for (var car in backendCars) {
      if (car.carId == null || car.carId == 0) {
        print("⚠️ Skipping car without backend_car_id");
        continue;
      }

      // Check if car already exists (by backend_car_id)
      final existing = await db.query(
        tableName,
        where: 'backend_car_id = ?',
        whereArgs: [car.carId],
        limit: 1,
      );

      final carMap = car.toMap();
      carMap['mode'] = 'online';
      carMap['sync_status'] = 'synced';
      carMap['last_sync_time'] = DateTime.now().toIso8601String();
      carMap['backend_car_id'] = car.carId;

      if (existing.isEmpty) {
        // INSERT new car
        batch.insert(
          tableName,
          carMap,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        insertedCount++;
      } else {
        // UPDATE existing car
        // Only update if backend version is newer
        final localUpdated = existing.first['updated_at']?.toString();
        final backendUpdated = carMap['updated_at']?.toString();

        if (backendUpdated != null && localUpdated != null) {
          try {
            final localDate = DateTime.parse(localUpdated);
            final backendDate = DateTime.parse(backendUpdated);

            if (backendDate.isAfter(localDate)) {
              batch.update(
                tableName,
                carMap,
                where: 'backend_car_id = ?',
                whereArgs: [car.carId],
              );
              updatedCount++;
            } else {
              print("⏳ Skipping older backend version for car ${car.carId}");
            }
          } catch (e) {
            // If date parsing fails, update anyway
            batch.update(
              tableName,
              carMap,
              where: 'backend_car_id = ?',
              whereArgs: [car.carId],
            );
            updatedCount++;
          }
        } else {
          // Update if we can't compare dates
          batch.update(
            tableName,
            carMap,
            where: 'backend_car_id = ?',
            whereArgs: [car.carId],
          );
          updatedCount++;
        }
      }
    }

    await batch.commit(noResult: true);
    print("🔄 Merge complete:new cars $insertedCount inserted, $updatedCount updated");
  }

// ✅ GET CARS BY BACKEND_ID (Helper)
  static Future<Map<String, dynamic>?> findCarByBackendId(int backendCarId) async {
    final db = await AppDatabase.database;
    final result = await db.query(
      tableName,
      where: 'backend_car_id = ?',
      whereArgs: [backendCarId],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }
}