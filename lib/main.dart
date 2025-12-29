
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:repo_agent_application/services/car_api_service.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

import 'data/prefernces.dart';
import 'database/app_database.dart';
import 'database/car_action_dao.dart';
import 'database/car_master_dao.dart';
import 'helpers/app_sync_manager.dart';
import 'helpers/device_utils.dart';
import 'package:window_manager/window_manager.dart';
import 'helpers/offline_search_db.dart';
import 'helpers/smart_sync_manager.dart';
import 'routes/my_app_route.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OfflineSearchDB.deleteDatabaseCompletely();


  // Set portrait orientation only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Shared Preferences
  await Preferences.initSharedPreference();

  // Initialize Localization
  await EasyLocalization.ensureInitialized();

  // Load saved language from Preferences
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String savedLangCode = prefs.getString('app_lang') ?? 'en';

  //delete db
 // await AppDatabase.deleteDatabase();

  // Initialize Database
  await AppDatabase.database;


// This deletes the .db file completely

  // await CarMasterDao.completelyRemoveTable();
  // await CarActionDao.completelyRemoveTable();

  //sk st

  // ✅ UPDATED: Check if first time
  final isCarTableEmpty = await CarMasterDao.isTableEmpty();

  if (isCarTableEmpty) {
    print("📥 First time → Fetching cars from backend");
    try {
      // Use fetchAllCars instead of fetchCars for consistency
      final cars = await CarApiService.fetchAllCars();
      if (cars.isNotEmpty) {
        await CarMasterDao.insertInitialCars(cars);

        print("✅ Loaded ${cars.length} cars initially");
      } else {
        print("⚠️ No cars returned from backend");
      }

      print("✅ Loaded ${cars.length} cars initially");
    } catch (e) {
      print("❌ Failed to load initial cars: $e");
    }
  } else {
    print("📁 Car table already has data");
  }

  // Check if actions table empty
  final isActionTableEmpty = await CarActionDao.isEmpty();
  if (isActionTableEmpty) {
    print("📥 Loading initial actions..CarActionDao.");
    // Optional: Load any existing actions from backend
    await CarApiService.getAgentSearchMasterData();
  }


  // ✅ 1️⃣ INITIALIZE SQLITE FOR DESKTOP (VERY IMPORTANT)
  // Initialize for desktop
  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }else{
    print("kkkiskIsWeb ${kIsWeb}");
  }



  // // Allow bad certificates
  // HttpOverrides.global = MyHttpOverrides();
  //set device ID
  final deviceId = await DeviceUtils.getDeviceId();
  print("DEVICE ID: $deviceId");
  await Preferences.setDeviceId(deviceId);

  // 🔥 Start global sync listener
 //AppSyncManager.instance.start();

  // ✅ STEP 7: INITIALIZE AUTO SYNC MANAGER
  await SimpleSyncManager().initialize();
  print("✅ Auto Sync Manager initialized");
  print("📱 Sync will run automatically every 30 minutes");




  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'),
        Locale('ms'),
      ],
      path: 'assets/lang',        // Folder path
      fallbackLocale: const Locale('en'),
      startLocale: Locale(savedLangCode),
      child: const MyAppRoute(),  // Your original app root
    ),
  );
}
