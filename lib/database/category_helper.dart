import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/material.dart';

class CategoryHelper {
  static Database? _database;
  static const String _tableName = 'categories';

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'categories.db');
    return await openDatabase(
      path,
      version: 2, // Mantém a versão 2
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createTable(db);
    }
  }

  Future<void> _createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        color TEXT NOT NULL
      )
    ''');
    await db.insert(_tableName, {
      'name': 'Geral',
      'color': '9e9e9e', // Cinza padrão (sem FF inicial)
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<Map<String, dynamic>>> getAllCategories() async {
    final db = await database;
    return await db.query(_tableName, orderBy: 'name ASC');
  }

  Future<int> addCategory(String name, String colorHex) async {
    final db = await database;
    if (name.trim().isEmpty) {
      throw ArgumentError('O nome da categoria não pode ser vazio.');
    }
    try {
      return await db.insert(_tableName, {
        'name': name.trim(),
        'color': colorHex, // Salva como string hexadecimal pura (RRGGBB)
      }, conflictAlgorithm: ConflictAlgorithm.fail);
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw ArgumentError('Categoria "$name" já existe.');
      }
      rethrow;
    }
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return await db.delete(
      _tableName,
      where: 'id = ? AND name != ?',
      whereArgs: [id, 'Geral'],
    );
  }

  // ✅ ADICIONADO: Método para deletar todas as categorias exceto 'Geral'
  Future<int> deleteAllCategoriesExceptDefault() async {
    final db = await database;
    return await db.delete(
      _tableName,
      where: 'name != ?',
      whereArgs: ['Geral'],
    );
  }

  Future<int> getCategoryCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM $_tableName');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> ensureDefaultCategory() async {
    try {
      final db = await database;
      await db.insert(_tableName, {
        'name': 'Geral',
        'color': '9e9e9e', // Cinza padrão (sem FF inicial)
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    } catch (e) {
      debugPrint('Erro ao garantir categoria padrão: $e');
    }
  }
}

