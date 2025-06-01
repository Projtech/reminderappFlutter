import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
// import 'package:file_picker/file_picker.dart'; // REMOVIDO TEMPORARIAMENTE
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart'; // ✅ Importar o DateFormat oficial
import '../database/database_helper.dart';
import '../database/category_helper.dart';
import '../models/reminder.dart';

class BackupService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final CategoryHelper _catHelper = CategoryHelper();

  Future<bool> _requestStoragePermission() async {
    // O file_picker geralmente lida com as permissões necessárias.
    // Como foi removido, apenas retornamos true por enquanto.
    return true;
  }

  Future<String?> exportBackup(BuildContext context) async {
    _showSnackBar(context, 'Funcionalidade de Backup temporariamente desativada.', Colors.orange);
    return null;
    /* // CÓDIGO ORIGINAL COMENTADO
    if (!await _requestStoragePermission()) {
      _showSnackBar(context, 'Permissão de armazenamento negada.', Colors.red);
      return null;
    }

    try {
      final reminders = await _dbHelper.getAllRemindersAsMaps();
      final categories = await _catHelper.getAllCategories();

      final backupData = {
        'version': 1,
        'createdAt': DateTime.now().toIso8601String(),
        'categories': categories,
        'reminders': reminders,
      };

      final jsonString = jsonEncode(backupData);

      // ✅ Usar intl.DateFormat
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Salvar Backup Como...',
        fileName: 'reminder_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (outputFile != null) {
        if (!outputFile.toLowerCase().endsWith('.json')) {
          outputFile += '.json';
        }
        final file = File(outputFile);
        await file.writeAsString(jsonString);
        _showSnackBar(context, 'Backup exportado com sucesso para $outputFile', Colors.green);
        return outputFile;
      } else {
        _showSnackBar(context, 'Exportação cancelada.', Colors.orange);
        return null;
      }
    } catch (e) {
      debugPrint('❌ Erro ao exportar backup: $e');
      _showSnackBar(context, 'Erro ao exportar backup: $e', Colors.red);
      return null;
    }
    */
  }

  Future<bool> importBackup(BuildContext context) async {
     _showSnackBar(context, 'Funcionalidade de Backup temporariamente desativada.', Colors.orange);
     return false;
    /* // CÓDIGO ORIGINAL COMENTADO
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonString = await file.readAsString();
        final backupData = jsonDecode(jsonString) as Map<String, dynamic>;

        if (backupData['version'] == null || backupData['categories'] == null || backupData['reminders'] == null) {
          throw Exception('Arquivo de backup inválido ou corrompido.');
        }

        _showSnackBar(context, 'Importando... Limpando dados antigos...', Colors.blue);
        await _dbHelper.deleteAllReminders();
        await _catHelper.deleteAllCategoriesExceptDefault();

        final categories = backupData['categories'] as List;
        for (var categoryMap in categories) {
          final name = categoryMap['name'] as String;
          final colorHex = categoryMap['color'] as String;
          if (name.toLowerCase() != 'geral') {
             try {
               await _catHelper.addCategory(name, colorHex);
             } catch (e) {
                debugPrint('Erro ao importar categoria $name: $e');
             }
          }
        }

        final reminders = backupData['reminders'] as List;
        for (var reminderMap in reminders) {
           try {
             final reminder = Reminder.fromMap(reminderMap as Map<String, dynamic>);
             // Use insertReminder (ou o nome correto do seu helper)
             await _dbHelper.insertReminder(reminder);
           } catch (e) {
              debugPrint('Erro ao importar lembrete: $reminderMap - Erro: $e');
           }
        }

        _showSnackBar(context, 'Backup importado com sucesso!', Colors.green);
        return true;

      } else {
        _showSnackBar(context, 'Importação cancelada.', Colors.orange);
        return false;
      }
    } catch (e) {
      debugPrint('❌ Erro ao importar backup: $e');
      _showSnackBar(context, 'Erro ao importar backup: $e', Colors.red);
      return false;
    }
    */
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
     if (ScaffoldMessenger.maybeOf(context) != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: color,
            behavior: SnackBarBehavior.floating,
          ),
        );
     }
  }
}

