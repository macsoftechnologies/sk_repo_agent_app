import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'car_action_table.dart';
import 'car_master_table.dart';

class AppDatabase {
  static Database? _db;
  static const String _databaseName = "repo_app.db";

  // Get database instance
  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  // Initialize database
  static Future<Database> _initDB() async {
    // Required for desktop platforms
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  // Create tables
  static Future<void> _onCreate(Database db, int version) async {
    await db.execute(CarMasterTable.createTable);
    await db.execute(CarActionTable.createTable);
    print("✅ Database created with tables");
  }

  // ✅ METHOD 1: DELETE ENTIRE DATABASE FILE
  static Future<void> deleteDatabase() async {
    try {
      if (_db != null) {
        await _db!.close();
        _db = null;
      }

      final dbPath = await getDatabasesPath();
      final path = join(dbPath, _databaseName);

      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        print("🗑️ Database file deleted: $path");
      } else {
        print("⚠️ Database file doesn't exist");
      }
    } catch (e) {
      print("❌ Error deleting database: $e");
      rethrow;
    }
  }

  // ✅ METHOD 2: DELETE AND RECREATE DATABASE
  static Future<void> resetDatabase() async {
    try {
      print("🔄 Resetting database...");

      // 1. Close and delete existing database
      await deleteDatabase();

      // 2. Recreate database
      _db = await _initDB();

      print("✅ Database reset complete - fresh start!");
    } catch (e) {
      print("❌ Error resetting database: $e");
      rethrow;
    }
  }

  // ✅ METHOD 3: DROP ALL TABLES (without deleting file)
  static Future<void> dropAllTables() async {
    final db = await database;

    try {
      await db.transaction((txn) async {
        await txn.execute('DROP TABLE IF EXISTS ${CarActionTable.tableName}');
        await txn.execute('DROP TABLE IF EXISTS ${CarMasterTable.tableName}');
      });

      print("🗑️ All tables dropped");

      // Recreate tables
      await _onCreate(db, 1);

      print("✅ Tables recreated");
    } catch (e) {
      print("❌ Error dropping tables: $e");
      rethrow;
    }
  }

  // ✅ METHOD 4: GET DATABASE INFO
  static Future<Map<String, dynamic>> getDatabaseInfo() async {
    try {
      final db = await database;
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, _databaseName);
      final file = File(path);

      final exists = await file.exists();
      final size = exists ? await file.length() : 0;

      // Get table info
      final carCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM ${CarMasterTable.tableName}')
      ) ?? 0;

      final actionCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM ${CarActionTable.tableName}')
      ) ?? 0;

      return {
        'path': path,
        'exists': exists,
        'size_bytes': size,
        'size_mb': (size / (1024 * 1024)).toStringAsFixed(2),
        'car_count': carCount,
        'action_count': actionCount,
        'total_records': carCount + actionCount,
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'path': 'Unknown',
        'exists': false,
      };
    }
  }

  // ✅ METHOD 5: CLOSE DATABASE CONNECTION
  static Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
      print("🔌 Database connection closed");
    }
  }

  // ✅ METHOD 6: CHECK IF DATABASE EXISTS
  static Future<bool> databaseExists() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);
    return await File(path).exists();
  }

  // ✅ METHOD 7: BACKUP DATABASE
  static Future<void> backupDatabase(String backupName) async {
    try {
      final dbPath = await getDatabasesPath();
      final sourcePath = join(dbPath, _databaseName);
      final backupPath = join(dbPath, '$backupName.db');

      final sourceFile = File(sourcePath);
      if (await sourceFile.exists()) {
        await sourceFile.copy(backupPath);
        print("💾 Database backed up to: $backupPath");
      } else {
        print("⚠️ No database to backup");
      }
    } catch (e) {
      print("❌ Error backing up database: $e");
    }
  }

  // ✅ METHOD 8: RESTORE FROM BACKUP
  static Future<void> restoreFromBackup(String backupName) async {
    try {
      final dbPath = await getDatabasesPath();
      final backupPath = join(dbPath, '$backupName.db');
      final targetPath = join(dbPath, _databaseName);

      final backupFile = File(backupPath);
      if (await backupFile.exists()) {
        // Close current connection
        await close();

        // Delete current database
        final currentFile = File(targetPath);
        if (await currentFile.exists()) {
          await currentFile.delete();
        }

        // Copy backup to current
        await backupFile.copy(targetPath);

        // Reinitialize
        _db = await _initDB();

        print("🔄 Database restored from backup: $backupName");
      } else {
        print("⚠️ Backup file not found: $backupPath");
      }
    } catch (e) {
      print("❌ Error restoring database: $e");
    }
  }
}