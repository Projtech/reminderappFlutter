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
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Criar tabela
    await db.execute('''
      CREATE TABLE $_tableName(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        color TEXT NOT NULL
      )
    ''');
    
    // Inserir categoria padrão diretamente
    await db.insert(_tableName, {
      'name': 'Adicione as categorias aqui',
      'color': '0xFF9E9E9E',
    });
  }

  Future<List<Map<String, dynamic>>> getAllCategories() async {
    final db = await database;
    return await db.query(_tableName, orderBy: 'name ASC');
  }

  Future<int> insertCategory(String name, String color) async {
    try {
      final db = await database;
      return await db.insert(_tableName, {
        'name': name,
        'color': color,
      });
    } catch (e) {
      return -1; // Categoria já existe
    }
  }

  Future<bool> deleteCategory(String name) async {
    // Verificar se pode deletar
    final count = await getCategoryCount();
    if (count <= 1) return false;
    
    if (name == 'Adicione as categorias aqui' && count <= 2) {
      return false;
    }
    
    final db = await database;
    final result = await db.delete(
      _tableName,
      where: 'name = ?',
      whereArgs: [name],
    );
    return result > 0;
  }

  Future<int> getCategoryCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // NOVO: Método simplificado para garantir categoria padrão
  Future<void> ensureDefaultCategory() async {
    try {
      final categories = await getAllCategories();
      
      if (categories.isEmpty) {
        final db = await database;
        await db.insert(_tableName, {
          'name': 'Adicione as categorias aqui',
          'color': '0xFF9E9E9E',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    } catch (e) {
      debugPrint('Erro ao garantir categoria padrão: $e');
    }
  }
}