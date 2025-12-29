import 'package:sqflite/sqflite.dart';
import '../models/car_action_model.dart';
import 'app_database.dart';

class CarActionDao {
  static const tableName = "car_actions";

  // ✅ 1. INITIAL LOAD FROM BACKEND (if any)
  static Future<void> insertInitialActions(List<CarActionModel> actions) async {
    if (actions.isEmpty) return;

    final db = await AppDatabase.database;
    final batch = db.batch();

    for (var action in actions) {
      final actionMap = action.toMap();
      actionMap['mode'] = 'online';
      actionMap['sync_status'] = 'synced';
      actionMap['backend_action_id'] = action.id;
      actionMap['last_sync_time'] = DateTime.now().toIso8601String();

      batch.insert(
        tableName,
        actionMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    print("📥 Inserted ${actions.length} actions from backend");
  }

  // ✅ 2. CREATE NEW LOCAL ACTION (User creates) - Your new method
  static Future<int> createLocalAction({
    required String regNo,
    required String actionType,
    String? status,
    int found = 0,
    String? gpsLocation,
    String? locationDetails,
    String? notes,
    int? createdBy,
  }) async {
    final db = await AppDatabase.database;

    final actionData = {
      'reg_no': regNo,
      'action_type': actionType,
      'status': status ?? actionType,
      'found': found,
      'gps_location': gpsLocation ?? '',
      'location_details': locationDetails ?? '',
      'notes': notes ?? '',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'created_by': createdBy,
      'mode': 'offline',           // 👈 Needs sync
      'sync_status': 'pending',    // 👈 Not sent yet
      'sync_attempts': 0,
      'backend_action_id': null,   // 👈 Will get from backend after sync
    };

    final id = await db.insert(
      tableName,
      actionData,
    );

    print("📝 Created local action #$id for $regNo (pending sync)");
    return id;
  }

  // ✅ ALWAYS INSERT NEW RECORD (Search History)
  static Future<int> insertSearchAction({
    required String regNo,
    required int agentId,
    required int found, // 1 = found, 0 = not found
    String? carMake,
    String? carModal,
    String? status,
    String? gpsLocation,
    required String locationDetails,
    required String notes,
    String? photo,
    int? carId,
    String? searchedAt,
  }) async {
    final db = await AppDatabase.database;

    final now = DateTime.now().toIso8601String();

    final actionData = {
      'agent_id': agentId,
      'reg_no': regNo.trim().toUpperCase(), // Normalize
      'action_type': 'search',
      'car_make': carMake,
      'car_modal': carModal,
      'status': status ?? (found == 1 ? 'found' : 'not_found'),
      'found': found,
      'gps_location': gpsLocation,
      'location_details': locationDetails,
      'notes': notes,
      'photo': photo,
      'car_id': carId,
      'searched_at': searchedAt ?? now,
      'created_at': now,
      'updated_at': now,
      'created_by': agentId,
      'mode': 'offline',        // Needs sync
      'sync_status': 'pending', // Not synced yet
      'sync_attempts': 0,
    };

    final id = await db.insert(tableName, actionData);

    print("🔍 Search recorded #$id for $regNo (found: $found)");
    return id;
  }
  // ✅ UPDATE ONLY LOCATION DETAILS AND NOTES FOR SPECIFIC ACTION ID
  static Future<Map<String, dynamic>> updateLocationAndNotesById({
    required int actionId,
    required String locationDetails,
    required String notes,
    bool markForSync = true,
  }) async {
    try {
      final db = await AppDatabase.database;

      print("🔄 Updating car action ID: $actionId");

      final updateData = {
        'location_details': locationDetails,
        'notes': notes,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (markForSync) {
        updateData['mode'] = 'offline';
        updateData['sync_status'] = 'pending';
      }

      final rowsAffected = await db.update(
        tableName,
        updateData,
        where: 'id = ?',
        whereArgs: [actionId],
      );

      if (rowsAffected > 0) {
        print("✅ Updated action ID: $actionId");

        final updatedRecord = await db.query(
          tableName,
          where: 'id = ?',
          whereArgs: [actionId],
          limit: 1,
        );

        return {
          'success': true,
          'message': 'Remarks Successfully Added!',
          'rows_affected': rowsAffected,
          'data': updatedRecord.isNotEmpty ? updatedRecord.first : null,
        };
      } else {
        return {
          'success': false,
          'message': 'No action found with ID: $actionId',
          'rows_affected': 0,
          'data': null,
        };
      }

    } catch (e) {
      print("❌ Error: $e");

      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
        'rows_affected': 0,
        'data': null,
      };
    }
  }

  // ✅ UPDATE ONLY LOCATION DETAILS AND NOTES FOR LATEST SEARCH
  static Future<Map<String, dynamic>> updateLatestLocationAndNotesByRegNo({
    required String regNo,
    required String locationDetails,
    required String notes,
    bool markForSync = true,
  }) async {
    try {
      final db = await AppDatabase.database;
      final normalizedRegNo = regNo.trim().toUpperCase();

      print("🔄 Updating latest action for: $normalizedRegNo");

      // Get the latest action ID for this reg_no
      final latestAction = await db.rawQuery('''
        SELECT id FROM $tableName 
        WHERE UPPER(TRIM(reg_no)) = ? 
        ORDER BY created_at DESC 
        LIMIT 1
      ''', [normalizedRegNo]);

      if (latestAction.isEmpty) {
        return {
          'success': false,
          'message': 'No search history found for: $regNo',
          'rows_affected': 0,
          'data': null,
        };
      }

      final latestId = latestAction.first['id'] as int;

      // Update using the ID
      return await updateLocationAndNotesById(
        actionId: latestId,
        locationDetails: locationDetails,
        notes: notes,
        markForSync: markForSync,
      );

    } catch (e) {
      print("❌ Error: $e");

      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
        'rows_affected': 0,
        'data': null,
      };
    }
  }

  // ✅ COMPATIBILITY METHOD (Your existing insertAction)
  static Future<int> insertAction(Map<String, dynamic> data) async {
    final db = await AppDatabase.database;

    // Ensure required fields
    final actionData = Map<String, dynamic>.from(data);

    // Normalize reg_no
    if (actionData.containsKey('reg_no')) {
      actionData['reg_no'] = actionData['reg_no'].toString().trim().toUpperCase();
    }

    // Set defaults
    if (!actionData.containsKey('action_type')) {
      actionData['action_type'] = 'search';
    }

    if (!actionData.containsKey('mode')) {
      actionData['mode'] = 'offline';
    }

    if (!actionData.containsKey('sync_status')) {
      actionData['sync_status'] = 'pending';
    }

    if (!actionData.containsKey('sync_attempts')) {
      actionData['sync_attempts'] = 0;
    }

    if (!actionData.containsKey('created_at')) {
      actionData['created_at'] = DateTime.now().toIso8601String();
    }

    if (!actionData.containsKey('updated_at')) {
      actionData['updated_at'] = DateTime.now().toIso8601String();
    }

    final id = await db.insert(tableName, actionData);
    print("📝 New action #$id for ${actionData['reg_no']}");
    return id;
  }

  // ✅ GET ALL SEARCHES FOR A CAR (History)
  static Future<List<Map<String, dynamic>>> getCarSearchHistory(String regNo) async {
    final db = await AppDatabase.database;
    final normalizedRegNo = regNo.trim().toUpperCase();

    return await db.query(
      tableName,
      where: 'UPPER(TRIM(reg_no)) = ? AND action_type = ?',
      whereArgs: [normalizedRegNo, 'search'],
      orderBy: 'searched_at DESC, created_at DESC',
    );
  }


  // ✅ COUNT TOTAL SEARCHES
  static Future<Map<String, int>> getSearchStats() async {
    final db = await AppDatabase.database;

    final total = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $tableName WHERE action_type = "search"')
    ) ?? 0;

    final found = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $tableName WHERE action_type = "search" AND found = 1')
    ) ?? 0;

    final notFound = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $tableName WHERE action_type = "search" AND found = 0')
    ) ?? 0;

    return {
      'total_searches': total,
      'found': found,
      'not_found': notFound,
    };
  }

  // ✅ 4. UPDATE LOCAL ACTION - Your new method
  static Future<int> updateActionLocally({
    required String regNo,
    required String status,
    required int found,
    required String gpsLocation,
    required String locationDetails,
    required String notes,
  }) async {
    final db = await AppDatabase.database;

    final rowsAffected = await db.update(
      tableName,
      {
        "status": status,
        "found": found,
        "gps_location": gpsLocation,
        "location_details": locationDetails,
        "notes": notes,
        "updated_at": DateTime.now().toIso8601String(),
        "mode": "offline",        // 👈 Mark for sync
        "sync_status": "pending", // 👈 Needs to be sent
      },
      where: "reg_no = ? AND action_type = 'search'",
      whereArgs: [regNo],
    );

    if (rowsAffected > 0) {
      print("📝 Updated action for $regNo (pending sync)");
    }

    return rowsAffected;
  }

  // ✅ 5. UPDATE ACTION BY REG NO - Your existing method (updated)
  static Future<int> updateActionByRegNo({
    required String regNo,
    required String status,
    required int found,
    required String gpsLocation,
    required String locationDetails,
    required String notes,
  }) async {
    final db = await AppDatabase.database;

    final rowsAffected = await db.update(
      tableName,
      {
        "status": status,
        "found": found,
        "gps_location": gpsLocation,
        "location_details": locationDetails,
        "notes": notes,
        "updated_at": DateTime.now().toIso8601String(),
        "mode": "offline", // 👈 MARK AS OFFLINE
        "sync_status": "pending", // 👈 Add sync status
      },
      where: "reg_no = ?",
      whereArgs: [regNo],
    );

    if (rowsAffected > 0) {
      print("✅ Updated action for $regNo | Mode: offline");
    }

    return rowsAffected;
  }

  // ✅ 6. GET PENDING ACTIONS FOR SYNC
  static Future<List<Map<String, dynamic>>> getPendingSyncActions() async {
    final db = await AppDatabase.database;

    return await db.query(
      tableName,
      where: 'mode = ? AND sync_status = ?',
      whereArgs: ['offline', 'pending'],
      orderBy: 'created_at ASC',
    );
  }

  // ✅ 7. MARK ACTIONS AS SYNCED (After successful POST)
  static Future<void> markActionsAsSynced(List<Map<String, dynamic>> actions) async {
    if (actions.isEmpty) return;

    final db = await AppDatabase.database;
    final batch = db.batch();

    for (var action in actions) {
      final backendId = action['backend_action_id'] ??
          DateTime.now().millisecondsSinceEpoch; // Temp ID

      batch.update(
        tableName,
        {
          'mode': 'online',
          'sync_status': 'synced',
          'last_sync_time': DateTime.now().toIso8601String(),
          'backend_action_id': backendId,
          'sync_attempts': (action['sync_attempts'] ?? 0) + 1,
        },
        where: 'id = ?',
        whereArgs: [action['id']],
      );
    }

    await batch.commit(noResult: true);
    print("✅ Marked ${actions.length} actions as synced");
  }

  // ✅ 8. INCREMENT SYNC ATTEMPTS (for failed syncs)
  static Future<void> incrementSyncAttempts(List<int> actionIds) async {
    if (actionIds.isEmpty) return;

    final db = await AppDatabase.database;
    final placeholders = List.filled(actionIds.length, '?').join(',');

    await db.rawUpdate('''
      UPDATE $tableName 
      SET sync_attempts = sync_attempts + 1,
          updated_at = ?
      WHERE id IN ($placeholders)
    ''', [DateTime.now().toIso8601String(), ...actionIds]);

    print("⚠️ Incremented sync attempts for ${actionIds.length} actions");
  }

  // ✅ 9. GET LAST 10 SEARCHES
  static Future<List<Map<String, dynamic>>> getLast10SearchedCars() async {
    final db = await AppDatabase.database;

    return await db.rawQuery('''
    SELECT reg_no, found, status, created_at, location_details
    FROM $tableName
    ORDER BY created_at DESC
    LIMIT 10
    ''');
  }

  // ✅ 10. CHECK IF TABLE EMPTY
  static Future<bool> isEmpty() async {
    final db = await AppDatabase.database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $tableName'),
    );
    return count == 0;
  }

  // ✅ 11. GET SYNC STATS
  static Future<Map<String, dynamic>> getSyncStats() async {
    final db = await AppDatabase.database;

    final total = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $tableName')
    ) ?? 0;

    final pending = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $tableName WHERE mode = "offline"')
    ) ?? 0;

    final failedSyncs = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $tableName WHERE sync_attempts > 3')
    ) ?? 0;

    return {
      'total_actions': total,
      'pending_sync': pending,
      'failed_syncs': failedSyncs,
      'last_sync': await _getLastSyncTime(),
    };
  }

  static Future<String> _getLastSyncTime() async {
    final db = await AppDatabase.database;
    final result = await db.rawQuery('''
      SELECT last_sync_time FROM $tableName 
      WHERE last_sync_time IS NOT NULL 
      ORDER BY last_sync_time DESC 
      LIMIT 1
    ''');

    return result.isNotEmpty ? result.first['last_sync_time'].toString() : 'Never';
  }

  // ✅ 12. FOR BACKEND ACTIONS (mode: online) - Your existing method
  static Future<void> insertBackendActions(List<CarActionModel> actions) async {
    final db = await AppDatabase.database;
    final batch = db.batch();

    for (var action in actions) {
      final actionMap = action.toMap();
      actionMap['mode'] = 'online'; // Backend data is already synced
      actionMap['sync_status'] = 'synced';
      actionMap['last_sync_time'] = DateTime.now().toIso8601String();

      batch.insert(
        tableName,
        actionMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    print("📥 Inserted ${actions.length} backend actions (mode: online)");
  }

  // ✅ 13. KEEP COMPATIBILITY METHOD FOR EXISTING CODE
  static Future<void> insertActions(List<CarActionModel> actions) async {
    // Call the new method
    await insertBackendActions(actions);
  }

  // ✅ 14. GET ACTION BY REG NO (Helper method)
  static Future<Map<String, dynamic>?> getActionByRegNo(String regNo) async {
    final db = await AppDatabase.database;

    final result = await db.query(
      tableName,
      where: 'reg_no = ?',
      whereArgs: [regNo],
      limit: 1,
    );

    return result.isNotEmpty ? result.first : null;
  }

  // ✅ 15. DELETE ACTION (if needed)
  static Future<int> deleteAction(int id) async {
    final db = await AppDatabase.database;

    final rowsAffected = await db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (rowsAffected > 0) {
      print("🗑️ Deleted action #$id");
    }

    return rowsAffected;
  }

  // ✅ 16. CLEAR ALL ACTIONS (for testing)
  static Future<void> clearAll() async {
    final db = await AppDatabase.database;
    await db.delete(tableName);
    print("🧹 Cleared all actions table");
  }

  static Future<void> completelyRemoveTable() async {
    final db = await AppDatabase.database;

    // 1. Delete table (schema + data)
    await db.execute('DROP TABLE IF EXISTS $tableName');
    print("action table deleted completely");


  }
}