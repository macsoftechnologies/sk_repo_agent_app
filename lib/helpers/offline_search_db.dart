import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class OfflineSearchDB {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    String dbPath;

    if (kIsWeb) {
      // Web - use IndexedDB or localStorage (sqflite doesn't work on web)
      throw Exception('Offline search not supported on web');
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      // Desktop platforms - use application documents directory
      final appDir = await getApplicationDocumentsDirectory();
      // Create a subdirectory for your app
      final appDataDir = Directory(path.join(appDir.path, 'RepoAgentApp'));
      if (!await appDataDir.exists()) {
        await appDataDir.create(recursive: true);
      }
      dbPath = path.join(appDataDir.path, 'offline_searches.db');
    } else {
      // Mobile platforms - use default database path
      final databasesPath = await getDatabasesPath();
      dbPath = path.join(databasesPath, 'offline_searches.db');
    }

    print('Database path: $dbPath');

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE offline_searches (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            reg_no TEXT,
            location_details TEXT,
            notes TEXT,
            car_id TEXT,
            car_make TEXT,
            status TEXT,
            photo TEXT,
            found INTEGER,
            searched_at TEXT
          )
        ''');
      },
    );
  }

  /// Insert offline search
  static Future<int> insert(Map<String, dynamic> data) async {
    try {
      final db = await database;
      return await db.insert('offline_searches', data);
    } catch (e) {
      print('Error inserting offline search: $e');
      rethrow;
    }
  }
  static Future<void> deleteDatabaseCompletely() async {
    try {
      String dbPath;

      if (kIsWeb) {
        throw Exception('Web not supported');
      }
      else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        final appDir = await getApplicationDocumentsDirectory();
        dbPath = path.join(appDir.path, 'RepoAgentApp', 'offline_searches.db');
      }
      else {
        final databasesPath = await getDatabasesPath();
        dbPath = path.join(databasesPath, 'offline_searches.db');
      }

      // Close DB if open
      if (_db != null) {
        await _db!.close();
        _db = null;
      }

      // Delete DB file
      await deleteDatabase(dbPath);

      print('✅ Offline database deleted completely');
    } catch (e) {
      print('❌ Failed to delete database: $e');
    }
  }


  /// Get all pending searches
  static Future<List<Map<String, dynamic>>> getAll() async {
    try {
      final db = await database;
      return await db.query('offline_searches', orderBy: 'id ASC');
    } catch (e) {
      print('Error getting offline searches: $e');
      return [];
    }
  }

  /// Get count of offline searches
  static Future<int> getCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT COUNT(*) FROM offline_searches');
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      print('Error getting count: $e');
      return 0;
    }
  }

  /// Delete a specific record
  static Future<void> delete(int id) async {
    try {
      final db = await database;
      await db.delete('offline_searches', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      print('Error deleting record $id: $e');
    }
  }

  /// Clear all after sync
  static Future<void> clear() async {
    try {
      final db = await database;
      await db.delete('offline_searches');
    } catch (e) {
      print('Error clearing database: $e');
    }
  }

  /// Check if database is accessible
  static Future<bool> testConnection() async {
    try {
      final db = await database;
      await db.rawQuery('SELECT 1');
      return true;
    } catch (e) {
      print('Database connection test failed: $e');
      return false;
    }
  }
}