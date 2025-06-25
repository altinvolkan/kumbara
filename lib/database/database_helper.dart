import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    debugPrint('Initializing database...');
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'kumbara.db');
    debugPrint('Database path: $path');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        debugPrint('Creating database tables...');

        // Users table
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL UNIQUE,
            email TEXT NOT NULL UNIQUE,
            password TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        debugPrint('Users table created');

        // Main accounts table
        await db.execute('''
          CREATE TABLE main_accounts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            balance REAL NOT NULL DEFAULT 0.0,
            created_at TEXT NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users (id)
          )
        ''');
        debugPrint('Main accounts table created');

        // Savings accounts table
        await db.execute('''
          CREATE TABLE savings_accounts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            balance REAL NOT NULL DEFAULT 0.0,
            target_amount REAL NOT NULL,
            target_date TEXT NOT NULL,
            created_at TEXT NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users (id)
          )
        ''');
        debugPrint('Savings accounts table created');

        // Transactions table
        await db.execute('''
          CREATE TABLE transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            account_id INTEGER,
            from_account_id INTEGER,
            to_account_id INTEGER,
            type TEXT NOT NULL,
            amount REAL NOT NULL,
            created_at TEXT NOT NULL,
            FOREIGN KEY (account_id) REFERENCES main_accounts (id),
            FOREIGN KEY (from_account_id) REFERENCES main_accounts (id),
            FOREIGN KEY (to_account_id) REFERENCES savings_accounts (id)
          )
        ''');
        debugPrint('Transactions table created');
      },
      onOpen: (db) {
        debugPrint('Database opened successfully');
      },
    );
  }

  Future<void> deleteDatabase() async {
    debugPrint('Deleting database...');
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'kumbara.db');
    await databaseFactory.deleteDatabase(path);
    _database = null;
    debugPrint('Database deleted');
  }

  // Debug method to print all tables and their contents
  Future<void> printDatabaseContent() async {
    final db = await database;
    debugPrint('\n--- DATABASE CONTENT ---');

    // Get all table names
    final tables = await db.query(
      'sqlite_master',
      where: 'type = ?',
      whereArgs: ['table'],
    );

    // Print content of each table
    for (var table in tables) {
      final tableName = table['name'] as String;
      if (tableName != 'android_metadata' && tableName != 'sqlite_sequence') {
        final rows = await db.query(tableName);
        debugPrint('\nTable: $tableName');
        debugPrint('Rows: ${rows.length}');
        for (var row in rows) {
          debugPrint(row.toString());
        }
      }
    }
    debugPrint('\n--- END DATABASE CONTENT ---');
  }
}
