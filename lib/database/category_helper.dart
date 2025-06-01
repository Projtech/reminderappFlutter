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
      version: 2, // Incrementa a versão para garantir a criação da tabela correta
      onCreate: _onCreate,
      onUpgrade: _onUpgrade, // Adiciona onUpgrade
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createTable(db);
  }

  // Adiciona onUpgrade para lidar com versões antigas sem a tabela
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Se a tabela não existir (versão antiga), cria
      await _createTable(db);
    }
  }

  // Método separado para criar a tabela e inserir padrão
  Future<void> _createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        color TEXT NOT NULL
      )
    ''');
    // Insere a categoria padrão 'Geral' se não existir
    await db.insert(_tableName, {
      'name': 'Geral',
      'color': 'ff9e9e9e', // Cinza padrão (sem 0x)
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }


  Future<List<Map<String, dynamic>>> getAllCategories() async {
    final db = await database;
    return await db.query(_tableName, orderBy: 'name ASC');
  }

  Future<int> addCategory(String name, String colorHex) async {
    final db = await database;
    // Garante que o nome não seja vazio
    if (name.trim().isEmpty) {
      throw ArgumentError('O nome da categoria não pode ser vazio.');
    }
    try {
      return await db.insert(_tableName, {
        'name': name.trim(),
        'color': colorHex, // Salva como string hexadecimal pura
      }, conflictAlgorithm: ConflictAlgorithm.fail); // Falha se o nome já existir
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw ArgumentError('Categoria "$name" já existe.');
      }
      rethrow; // Re-lança outros erros de banco de dados
    }
  }

  // MODIFICADO: Método para deletar por ID
  Future<int> deleteCategory(int id) async {
    final db = await database;
    // Opcional: Buscar o nome antes de deletar para logs ou mensagens, se necessário
    // final category = await db.query(_tableName, where: 'id = ?', whereArgs: [id], limit: 1);
    // if (category.isEmpty) return 0; // Categoria não encontrada
    // final categoryName = category.first['name'] as String;
    // if (categoryName == 'Geral') return 0; // Não permite excluir 'Geral'

    return await db.delete(
      _tableName,
      where: 'id = ? AND name != ?', // Adiciona verificação para não excluir 'Geral'
      whereArgs: [id, 'Geral'],
    );
  }

  Future<int> getCategoryCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM $_tableName');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Garante que a categoria 'Geral' exista
  Future<void> ensureDefaultCategory() async {
    try {
      final db = await database;
      await db.insert(_tableName, {
        'name': 'Geral',
        'color': 'ff9e9e9e', // Cinza padrão (sem 0x)
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    } catch (e) {
      debugPrint('Erro ao garantir categoria padrão: $e');
    }
  }
}

