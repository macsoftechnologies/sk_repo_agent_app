import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/car_action_dao.dart';
import '../database/car_master_dao.dart';
import '../services/car_api_service.dart';

class SimpleSyncManager {
  static final SimpleSyncManager _instance = SimpleSyncManager._internal();
  factory SimpleSyncManager() => _instance;
  SimpleSyncManager._internal();

  Timer? _syncTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;


  bool _isSyncing = false;
  bool _initialized = false;

  final Duration _syncInterval = const Duration(minutes: 30);
  final String _lastSyncKey = 'last_sync_time';

  /// ✅ INITIALIZE (CALL ONCE FROM main.dart)
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    print("🚀 SimpleSyncManager initializing...");

    // 1️⃣ Start periodic sync (30 min)
    _startPeriodicSync();

    // 2️⃣ Listen to internet changes
    _listenToConnectivity();

    // 3️⃣ Initial sync after app start
    _initialDelayedSync();

    print("✅ SimpleSyncManager initialized");
  }

  /// ⏱ PERIODIC SYNC (EVERY 30 MIN)
  void _startPeriodicSync() {
    _syncTimer?.cancel();

    _syncTimer = Timer.periodic(_syncInterval, (_) async {
      print("⏰ Periodic sync triggered");
      await _triggerSync();
    });
  }

  /// 📶 INTERNET CONNECTIVITY LISTENER
  void _listenToConnectivity() {
    _connectivitySub?.cancel();

    _connectivitySub =
        Connectivity().onConnectivityChanged.listen(
              (List<ConnectivityResult> results) async {
            final hasInternet =
            results.any((r) => r != ConnectivityResult.none);

            if (hasInternet) {
              print("📶 Internet available → triggering sync");
              await _triggerSync();
            } else {
              print("📴 Internet lost");
            }
          },
        );

  }

  /// 🔁 INITIAL SYNC (10 SEC AFTER APP START)
  void _initialDelayedSync() {
    Future.delayed(const Duration(seconds: 10), () async {
      print("🔄 Initial delayed sync");
      await _triggerSync();
    });
  }

  /// 🔄 CORE SYNC TRIGGER
  Future<void> _triggerSync() async {
    if (_isSyncing) {
      print("⏳ Sync already running, skipping...");
      return;
    }

    final hasInternet = await _hasInternet();
    if (!hasInternet) {
      print("📴 No internet → waiting");
      return;
    }

    _isSyncing = true;
    final start = DateTime.now();

    try {
      print("🔄 Sync started at ${start.toIso8601String()}");

      // STEP 1️⃣ PUSH LOCAL DATA
      await _pushLocalChanges();

      // STEP 2️⃣ PULL BACKEND DATA
      await _pullFromBackend();

      await _saveLastSyncTime();

      print("✅ Sync completed in ${DateTime.now().difference(start).inSeconds}s");
    } catch (e) {
      print("❌ Sync error: $e");
    } finally {
      _isSyncing = false;
    }
  }

  /// 🌐 INTERNET CHECK
  Future<bool> _hasInternet() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  /// ⬆️ PUSH LOCAL CHANGES
  Future<void> _pushLocalChanges() async {
    print("⬆️ Pushing local changes");

    // Cars
    final pendingCars = await CarMasterDao.getPendingSyncCars();
    if (pendingCars.isNotEmpty) {
      final success = await CarApiService.syncCars(pendingCars);
      if (success) {
        final regNos =
        pendingCars.map((e) => e['reg_no'].toString()).toList();
        await CarMasterDao.markCarsAsSynced(regNos);
        print("Synced Master data${pendingCars.length} cars");
      }
    }

    // Actions
    final pendingActions = await CarActionDao.getPendingSyncActions();
    if (pendingActions.isNotEmpty) {
      final success = await CarApiService.syncActions(pendingActions);
      if (success) {
        await CarActionDao.markActionsAsSynced(pendingActions);
        print("Synced Car actions${pendingActions.length} actions");
      }
    }
  }

  /// ⬇️ PULL UPDATED DATA
  Future<void> _pullFromBackend() async {
    print("⬇️ Pulling backend updates");

    final lastCreatedAt = await CarMasterDao.getLatestCreatedAt();
    final lastUpdatedAt = await CarMasterDao.getLatestUpdatedAt();
    final bool isLocalDataEmpty = (lastCreatedAt == null && lastUpdatedAt == null);
    if (isLocalDataEmpty) {
      print("📭 Local DB empty. Performing initial full sync...");
      // Option 1: Call a dedicated "initial sync" method
      final allCars = await CarApiService.fetchAllCarsOld(); // Your existing method
      if (allCars.isNotEmpty) {
        await CarMasterDao.insertInitialCars(allCars); // Use initial insert
        print("✅ Initial sync complete: ${allCars.length} cars loaded");
      }
      return; // Exit, as we've done a full sync
    }

    final cars = await CarApiService.fetchNewAndUpdatedMasterCars(
      lastCreatedAt: lastCreatedAt,
      lastUpdatedAt: lastUpdatedAt,
    );

    if (cars.isNotEmpty) {
      await CarMasterDao.mergeCarsFromBackend(cars);
      print("📥 Merged ${cars.length} cars from backend");
    }
  }

  /// 💾 SAVE LAST SYNC TIME
  Future<void> _saveLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
  }

  /// 🛑 STOP (LOGOUT / APP CLOSE)
  void stop() {
    _syncTimer?.cancel();
    _connectivitySub?.cancel();
    _syncTimer = null;
    _connectivitySub = null;
    _initialized = false;

    print("🛑 SimpleSyncManager stopped");
  }
}
