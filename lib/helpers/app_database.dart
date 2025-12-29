import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../database/car_action_table.dart';
import '../database/car_master_table.dart';

class AppDatabase {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final path = await getDatabasesPath();
    final dbPath = join(path, 'repo_agent.db');

    return await openDatabase(
      dbPath,
      version: 2, // Increment for migrations
      onCreate: (db, version) async {
        // Create tables
        await db.execute(CarMasterTable.createTable);
        await db.execute(CarActionTable.createTable);
        print("✅ Tables created successfully");
      }
    );
  }

  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}