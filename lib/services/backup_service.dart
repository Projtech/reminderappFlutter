import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
// import 'package:permission_handler/permission_handler.dart'; // REMOVIDO - Não usado
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../database/category_helper.dart';
import '../models/reminder.dart';
import 'notification_service.dart';

class BackupService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final CategoryHelper _catHelper = CategoryHelper();

  // Função auxiliar para mostrar SnackBar
  void _showSnackBar(BuildContext context, String message, Color color) {
    // A verificação 'mounted' já está aqui, o que é bom.
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<String?> exportBackup(BuildContext context) async {
    // Removido o bloco de código comentado relacionado à permissão, que continha dead code.

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

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Salvar Backup Como',
        fileName: 'lembretes_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json',
        bytes: utf8.encode(jsonString),
      );

      if (outputFile == null) {
        // Usuário cancelou ou falhou ao salvar
        // Adicionando verificação explícita de 'mounted' antes de usar o context após await
        if (context.mounted) {
           _showSnackBar(context, 'Exportação cancelada ou falhou.', Colors.grey);
        }
        return null;
      }

      // Adicionando verificação explícita de 'mounted' antes de usar o context após await
      if (context.mounted) {
         _showSnackBar(context, 'Backup exportado com sucesso!', Colors.green);
      }
      return outputFile;

    } catch (e) {
      debugPrint('❌ Erro ao exportar backup: $e');
      // Adicionando verificação explícita de 'mounted' antes de usar o context após await
      if (context.mounted) {
         _showSnackBar(context, 'Erro ao exportar backup: ${e.toString()}', Colors.red);
      }
      return null;
    }
  }

  Future<bool> importBackup(BuildContext context) async {
    try {
      // Removido o bloco de código comentado relacionado à permissão, que continha dead code.

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) {
        // Usuário cancelou ou não selecionou um arquivo válido
        // Adicionando verificação explícita de 'mounted' antes de usar o context após await
        if (context.mounted) {
           _showSnackBar(context, 'Importação cancelada ou nenhum arquivo selecionado.', Colors.grey);
        }
        return false;
      }

      final filePath = result.files.single.path!;
      final file = File(filePath);
      final jsonString = await file.readAsString();
      final backupData = jsonDecode(jsonString) as Map<String, dynamic>;

      if (backupData['version'] != 1 || backupData['categories'] == null || backupData['reminders'] == null) {
        throw const FormatException('Formato de backup inválido ou não suportado.');
      }

      final categories = (backupData['categories'] as List).cast<Map<String, dynamic>>();
      final reminders = (backupData['reminders'] as List).cast<Map<String, dynamic>>();

      await _catHelper.deleteAllCategoriesExceptDefault();
      await _dbHelper.deleteAllReminders();

      for (final categoryMap in categories) {
        if (categoryMap['name']?.toLowerCase() != 'geral') {
           final name = categoryMap['name'] as String?;
           final color = categoryMap['color'] as String?;
           if (name != null && color != null) {
             await _catHelper.addCategory(name, color);
           } else {
             debugPrint("Categoria inválida no backup (nome ou cor nulos): $categoryMap");
           }
        }
      }

      for (final reminderMap in reminders) {
        try {
          final reminder = Reminder.fromMap(reminderMap);
          await _dbHelper.insertReminder(reminder);
          await NotificationService.scheduleNotification(
            id: reminder.id!,
            title: reminder.title,
            description: reminder.description,
            scheduledDate: reminder.dateTime,
            category: reminder.category,
          );
        } catch (e) {
           debugPrint("Erro ao importar lembrete individual: $reminderMap - Erro: $e");
        }
      }

      // Adicionando verificação explícita de 'mounted' antes de usar o context após await
      if (context.mounted) {
         _showSnackBar(context, 'Backup importado com sucesso!', Colors.green);
      }
      return true;

    } catch (e) {
      debugPrint('❌ Erro ao importar backup: $e');
      // Adicionando verificação explícita de 'mounted' antes de usar o context após await
      if (context.mounted) {
         _showSnackBar(context, 'Erro ao importar backup: ${e.toString()}', Colors.red);
      }
      return false;
    }
  }
}

