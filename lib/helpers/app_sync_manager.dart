import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../data/prefernces.dart';
import '../helpers/offline_search_sync_service.dart';
import '../services/car_master_sync_service.dart';

class AppSyncManager {
  AppSyncManager._internal();
  static final AppSyncManager instance = AppSyncManager._internal();

  Timer? _syncTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  bool _isSyncing = false;
  bool _started = false;

  /// 🚀 START GLOBAL SYNC MANAGER
  Future<void> start() async {
    if (_started) return;
    _started = true;

    print("🚀 AppSyncManager started");

    // 🔁 Immediate sync on app start
    await _syncOfflineData();

    // ⏱ Sync every 30 minutes
    _syncTimer = Timer.periodic(
      const Duration(minutes: 30),
          (_) async {
        await _syncOfflineData();
      },
    );

    // 📶 Sync when internet becomes available
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((results) async {
          if (!results.contains(ConnectivityResult.none)) {
            print("📶 Internet available → triggering sync");
            await _syncOfflineData();
          }
        });
  }

  /// 🔄 CORE SYNC FUNCTION
  Future<void> _syncOfflineData() async {
    if (_isSyncing) {
      print("⏳ Sync already running, skipping...");
      return;
    }

    final userData = await Preferences.getUserDetails();
    if (userData == null || userData.isEmpty) {
      print("⚠️ No user data found. Sync skipped.");
      return;
    }

    final decoded = jsonDecode(userData);

    final adminId = decoded["admin_id"];
    final deviceToken = decoded["device_token"];

    if (adminId == null || deviceToken == null) {
      print("⚠️ Missing adminId or deviceToken");
      return;
    }

    _isSyncing = true;
    print("🔄 Sync started (adminId: $adminId)");

    try {
      // 🔍 Sync offline searches
      await OfflineSearchSyncService.sync(
        adminId: adminId.toString(),
        deviceToken: deviceToken.toString(),
      );

      // 🚗 Sync updated car master records
      await CarMasterSyncService.sync();

      print("✅ Sync completed successfully");
    } catch (e) {
      print("❌ Sync failed: $e");
    } finally {
      _isSyncing = false;
    }
  }

  /// 🛑 STOP SYNC (Call on logout)
  void stop() {
    _syncTimer?.cancel();
    _connectivitySub?.cancel();

    _syncTimer = null;
    _connectivitySub = null;
    _started = false;

    print("🛑 AppSyncManager stopped");
  }
}
