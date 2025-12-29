// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:flutter/foundation.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// import '../database/car_action_dao.dart';
// import '../database/car_master_dao.dart';
// import 'car_api_service.dart';
//
// class SimpleSyncManager {
//   static final SimpleSyncManager _instance = SimpleSyncManager._internal();
//   factory SimpleSyncManager() => _instance;
//   SimpleSyncManager._internal();
//
//   Timer? _syncTimer;
//   bool _isSyncing = false;
//   final Duration _syncInterval = Duration(minutes: 30);
//   final String _lastSyncKey = 'last_sync_time';
//   final String _syncStatsKey = 'sync_statistics';
//
//   // ✅ INITIALIZE - CALL THIS FROM MAIN.DART
//   Future<void> initialize() async {
//     print("🚀 Simple Sync Manager Initializing...");
//
//     // Cancel any existing timer
//     _syncTimer?.cancel();
//
//     // Start automatic timer (30-minute intervals)
//     _startAutomaticTimer();
//
//     // Perform initial sync after 10 seconds
//     _scheduleInitialSync();
//
//     print("✅ Simple Sync Manager Ready");
//     print("⏰ Auto-sync scheduled every ${_syncInterval.inMinutes} minutes");
//     print("📱 Sync will run automatically when app is open");
//   }
//
//   // ✅ START AUTOMATIC TIMER
//   void _startAutomaticTimer() {
//     _syncTimer = Timer.periodic(_syncInterval, (timer) {
//       print("⏰ Automatic sync timer triggered");
//       _triggerSync();
//     });
//   }
//
//   // ✅ SCHEDULE INITIAL SYNC
//   void _scheduleInitialSync() {
//     Timer(Duration(seconds: 10), () {
//       print("🔄 Performing initial sync");
//       _triggerSync();
//     });
//   }
//
//   // ✅ TRIGGER SYNC (AUTOMATIC OR MANUAL)
//   Future<void> _triggerSync() async {
//     if (_isSyncing) {
//       print("⏳ Sync already in progress, skipping...");
//       return;
//     }
//
//     // Check internet connection
//     final hasInternet = await _checkInternetConnection();
//     if (!hasInternet) {
//       print("📶 No internet connection, skipping sync");
//       return;
//     }
//
//     _isSyncing = true;
//     final startTime = DateTime.now();
//     final syncId = DateTime.now().millisecondsSinceEpoch;
//
//     try {
//       print("🔄 [Sync #$syncId] Starting at ${startTime.toIso8601String()}");
//
//       // Perform sync operations
//       await _performSyncOperations();
//
//       final duration = DateTime.now().difference(startTime);
//       print("✅ [Sync #$syncId] Completed in ${duration.inSeconds} seconds");
//
//       // Update statistics
//       await _updateSyncStatistics(true);
//
//     } catch (e) {
//       print("❌ [Sync #$syncId] Failed: $e");
//       await _updateSyncStatistics(false);
//     } finally {
//       _isSyncing = false;
//     }
//   }
//
//   // ✅ CHECK INTERNET CONNECTION
//   Future<bool> _checkInternetConnection() async {
//     try {
//       final connectivity = await Connectivity().checkConnectivity();
//       return connectivity != ConnectivityResult.none;
//     } catch (e) {
//       print("❌ Error checking connectivity: $e");
//       return false;
//     }
//   }
//
//   // ✅ PERFORM SYNC OPERATIONS
//   Future<void> _performSyncOperations() async {
//     // STEP 1: Push local changes to backend
//     await _pushLocalChanges();
//
//     // STEP 2: Pull new data from backend
//     await _pullFromBackend();
//   }
//
//   // ✅ PUSH LOCAL CHANGES TO BACKEND
//   Future<void> _pushLocalChanges() async {
//     print("⬆️  Pushing local changes to backend...");
//
//     int totalPushed = 0;
//
//     // Push pending cars
//     final pendingCars = await CarMasterDao.getPendingSyncCars();
//     if (pendingCars.isNotEmpty) {
//       print("📤 Found ${pendingCars.length} cars to sync");
//
//       try {
//         final success = await CarApiService.syncCars(pendingCars);
//         if (success) {
//           final regNumbers = pendingCars.map((car) => car['reg_no'].toString()).toList();
//           await CarMasterDao.markCarsAsSynced(regNumbers);
//           totalPushed += pendingCars.length;
//           print("✅ Successfully pushed ${pendingCars.length} cars");
//         } else {
//           print("⚠️ Failed to push cars");
//         }
//       } catch (e) {
//         print("❌ Error pushing cars: $e");
//       }
//     }
//
//     // Push pending actions
//     final pendingActions = await CarActionDao.getPendingSyncActions();
//     if (pendingActions.isNotEmpty) {
//       print("📤 Found ${pendingActions.length} actions to sync");
//
//       try {
//         final success = await CarApiService.syncActions(pendingActions);
//         if (success) {
//           await CarActionDao.markActionsAsSynced(pendingActions);
//           totalPushed += pendingActions.length;
//           print("✅ Successfully pushed ${pendingActions.length} actions");
//         } else {
//           print("⚠️ Failed to push actions");
//         }
//       } catch (e) {
//         print("❌ Error pushing actions: $e");
//       }
//     }
//
//     if (totalPushed == 0) {
//       print("📭 No pending changes to push");
//     } else {
//       print("📊 Total pushed: $totalPushed items");
//     }
//   }
//
//   // ✅ PULL FROM BACKEND
//   Future<void> _pullFromBackend() async {
//     print("⬇️  Pulling updates from backend...");
//
//     try {
//       // Get latest timestamps from local DB
//       final lastCreatedAt = await CarMasterDao.getLatestCreatedAt();
//       final lastUpdatedAt = await CarMasterDao.getLatestUpdatedAt();
//
//       print("📅 Fetching updates since: Created=$lastCreatedAt, Updated=$lastUpdatedAt");
//
//       // Fetch only new/updated records
//       final deltaCars = await CarApiService.fetchNewAndUpdatedMasterCars(
//         lastCreatedAt: lastCreatedAt,
//         lastUpdatedAt: lastUpdatedAt,
//       );
//
//       if (deltaCars.isNotEmpty) {
//         print("📥 Received ${deltaCars.length} new/updated cars");
//
//         // Smart merge into local DB
//         await CarMasterDao.mergeCarsFromBackend(deltaCars);
//
//         print("✅ Successfully merged ${deltaCars.length} cars");
//       } else {
//         print("📭 No new updates from backend");
//       }
//
//     } catch (e) {
//       print("❌ Error pulling from backend: $e");
//       // Don't rethrow - allow app to continue working offline
//     }
//   }
//
//   // ✅ UPDATE SYNC STATISTICS
//   Future<void> _updateSyncStatistics(bool success) async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final now = DateTime.now();
//
//       // Save last sync time
//       await prefs.setString(_lastSyncKey, now.toIso8601String());
//
//       // Load existing stats
//       final statsJson = prefs.getString(_syncStatsKey);
//       Map<String, dynamic> stats = {};
//
//       if (statsJson != null) {
//         try {
//           stats = Map<String, dynamic>.from(jsonDecode(statsJson));
//         } catch (e) {
//           print("⚠️ Error parsing stats: $e");
//         }
//       }
//
//       // Update stats
//       stats['total_syncs'] = (stats['total_syncs'] ?? 0) + 1;
//       stats['last_sync'] = now.toIso8601String();
//       stats['last_sync_success'] = success;
//
//       if (success) {
//         stats['successful_syncs'] = (stats['successful_syncs'] ?? 0) + 1;
//       } else {
//         stats['failed_syncs'] = (stats['failed_syncs'] ?? 0) + 1;
//       }
//
//       // Save updated stats
//       await prefs.setString(_syncStatsKey, jsonEncode(stats));
//
//     } catch (e) {
//       print("❌ Error updating sync stats: $e");
//     }
//   }
//
//   // ✅ GET LAST SYNC TIME
//   Future<DateTime?> getLastSyncTime() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final timeString = prefs.getString(_lastSyncKey);
//       return timeString != null ? DateTime.parse(timeString) : null;
//     } catch (e) {
//       return null;
//     }
//   }
//
//   // ✅ GET SYNC STATISTICS
//   Future<Map<String, dynamic>> getSyncStatistics() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final statsJson = prefs.getString(_syncStatsKey);
//
//       if (statsJson != null) {
//         return Map<String, dynamic>.from(jsonDecode(statsJson));
//       }
//     } catch (e) {
//       print("❌ Error getting sync stats: $e");
//     }
//
//     return {
//       'total_syncs': 0,
//       'successful_syncs': 0,
//       'failed_syncs': 0,
//       'last_sync': null,
//       'last_sync_success': false,
//     };
//   }
//
//   // ✅ MANUAL SYNC TRIGGER (Optional - for user to force sync)
//   Future<void> manualSync() async {
//     print("🔵 User requested manual sync");
//     await _triggerSync();
//   }
//
//   // ✅ CHECK IF SYNCING
//   bool get isSyncing => _isSyncing;
//
//   // ✅ STOP SYNC MANAGER
//   void stop() {
//     _syncTimer?.cancel();
//     _syncTimer = null;
//     print("🛑 Simple Sync Manager Stopped");
//   }
//
//   // ✅ GET NEXT SYNC TIME
//   DateTime? getNextSyncTime() {
//     if (_syncTimer == null) return null;
//     return DateTime.now().add(_syncInterval);
//   }
//
//   // ✅ GET TIME UNTIL NEXT SYNC
//   Duration? getTimeUntilNextSync() {
//     final nextSync = getNextSyncTime();
//     if (nextSync == null) return null;
//     return nextSync.difference(DateTime.now());
//   }
// }