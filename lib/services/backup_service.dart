import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../database/category_helper.dart';
import '../database/note_helper.dart'; // ✅ ADICIONADO: Import do note_helper
import '../models/reminder.dart';
import 'notification_service.dart';
import '../models/note.dart';

class BackupService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final CategoryHelper _catHelper = CategoryHelper();
  final NoteHelper _noteHelper = NoteHelper(); // ✅ ADICIONADO: Instância do note_helper

  // Função auxiliar para mostrar SnackBar
  void _showSnackBar(BuildContext context, String message, Color color) {
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
    try {
      // MODIFICADO: Coletando dados dos 3 bancos
      final reminders = await _dbHelper.getAllRemindersAsMaps();
      final categories = await _catHelper.getAllCategories();
      final notes = await _noteHelper.getAllNotesAsMaps(); //  ADICIONADO: Coletando anotações

      final backupData = {
        'version': 1,
        'createdAt': DateTime.now().toIso8601String(),
        'categories': categories,
        'reminders': reminders,
        'notes': notes, //  ADICIONADO: Incluindo anotações no backup
      };

      final jsonString = jsonEncode(backupData);

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Salvar Backup Como',
        fileName: 'lembretes_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json',
        bytes: utf8.encode(jsonString),
      );

      if (outputFile == null) {
        if (context.mounted) {
           _showSnackBar(context, 'Exportação cancelada ou falhou.', Colors.grey);
        }
        return null;
      }

      if (context.mounted) {
         _showSnackBar(context, 'Backup exportado com sucesso!', Colors.green);
      }
      return outputFile;

    } catch (e) {
      if (context.mounted) {
         _showSnackBar(context, 'Erro ao exportar backup: ${e.toString()}', Colors.red);
      }
      return null;
    }
  }

  Future<bool> importBackup(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) {
        if (context.mounted) {
           _showSnackBar(context, 'Importação cancelada ou nenhum arquivo selecionado.', Colors.grey);
        }
        return false;
      }

      final filePath = result.files.single.path!;
      final file = File(filePath);
      final jsonString = await file.readAsString();
      final backupData = jsonDecode(jsonString) as Map<String, dynamic>;

      // MODIFICADO: Validação incluindo notes
      if (backupData['version'] != 1 || 
          backupData['categories'] == null || 
          backupData['reminders'] == null ||
          backupData['notes'] == null) {
        throw const FormatException('Formato de backup inválido ou não suportado.');
      }

      final categories = (backupData['categories'] as List).cast<Map<String, dynamic>>();
      final reminders = (backupData['reminders'] as List).cast<Map<String, dynamic>>();
      final notes = (backupData['notes'] as List).cast<Map<String, dynamic>>(); // ✅ ADICIONADO: Extraindo anotações

      //  MODIFICADO: Limpando os 3 bancos
      await _catHelper.deleteAllCategoriesExceptDefault();
      await _dbHelper.deleteAllReminders();
      await _noteHelper.deleteAllNotes(); // ✅ ADICIONADO: Limpando anotações

      // Importando categorias
      for (final categoryMap in categories) {
        if (categoryMap['name']?.toLowerCase() != 'geral') {
           final name = categoryMap['name'] as String?;
           final color = categoryMap['color'] as String?;
           if (name != null && color != null) {
             await _catHelper.addCategory(name, color);
           }
        }
      }

      // Importando lembretes
      for (final reminderMap in reminders) {
        try {
          final reminder = Reminder.fromMap(reminderMap);
          final insertedId = await _dbHelper.insertReminder(reminder);
          
          // Reagendar notificação se necessário
          if (reminder.notificationsEnabled && 
              !reminder.isCompleted && 
              reminder.dateTime.isAfter(DateTime.now())) {
            await NotificationService.scheduleNotification(
              id: insertedId,
              title: reminder.title,
              description: reminder.description,
              scheduledDate: reminder.dateTime,
              category: reminder.category,
            );
          }
        } catch (e) {
          // Log do erro individual sem interromper o processo
        }
      }

      //  ADICIONADO: Importando anotações
      for (final noteMap in notes) {
        try {
          // Remove o ID para que seja gerado automaticamente
          final noteMapWithoutId = Map<String, dynamic>.from(noteMap);
          noteMapWithoutId.remove('id');
          
          // Cria a anotação sem ID
          final note = Note.fromMap(noteMapWithoutId);
          await _noteHelper.insertNote(note);
        } catch (e) {
          // Log do erro individual sem interromper o processo
        }
      }

      if (context.mounted) {
         _showSnackBar(context, 'Backup importado com sucesso!', Colors.green);
      }
      return true;

    } catch (e) {
      if (context.mounted) {
         _showSnackBar(context, 'Erro ao importar backup: ${e.toString()}', Colors.red);
      }
      return false;
    }
  }
}