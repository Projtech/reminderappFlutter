import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../database/category_helper.dart';
import '../database/note_helper.dart';
import '../models/reminder.dart';
import '../services/notification_service.dart';
import '../models/note.dart';

class BackupService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final CategoryHelper _catHelper = CategoryHelper();
  final NoteHelper _noteHelper = NoteHelper();

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

  // ✅ NOVO: Método para mostrar opções de backup
  Future<String?> exportBackup(BuildContext context) async {
    // Mostrar diálogo de opções de backup
    final backupOption = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Opções de Backup'),
        content: const Text(
          'Escolha o tipo de backup que deseja exportar:'
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'active'),
            child: const Text('Apenas Dados Ativos'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'complete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: const Text('Backup Completo (com Lixeira)'),
          ),
        ],
      ),
    );

    if (backupOption == null) return null;

    final includeTrash = backupOption == 'complete';
    return await _performExport(context, includeTrash);
  }

  // ✅ NOVO: Realizar exportação com ou sem lixeira
  Future<String?> _performExport(BuildContext context, bool includeTrash) async {
    try {
      // Coletando dados ativos
      final reminders = await _dbHelper.getAllRemindersAsMaps();
      final categories = await _catHelper.getAllCategories();
      final notes = await _noteHelper.getAllNotesAsMaps();

      // ✅ NOVO: Coletando dados da lixeira se solicitado
      final deletedReminders = includeTrash ? await _dbHelper.getDeletedRemindersAsMaps() : <Map<String, dynamic>>[];
      final deletedNotes = includeTrash ? await _noteHelper.getDeletedNotesAsMaps() : <Map<String, dynamic>>[];

      final backupData = {
        'version': includeTrash ? 3 : 2, // ✅ VERSÃO 3 para backup com lixeira
        'createdAt': DateTime.now().toIso8601String(),
        'includeTrash': includeTrash,
        'categories': categories,
        'reminders': reminders,
        'notes': notes,
        if (includeTrash) ...{
          'deletedReminders': deletedReminders,
          'deletedNotes': deletedNotes,
        },
      };

      final jsonString = jsonEncode(backupData);

      final fileName = includeTrash 
          ? 'backup_completo_${DateFormat('dd-MM-yyyy').format(DateTime.now())}.json'
          : 'backup_ativo_${DateFormat('dd-MM-yyyy').format(DateTime.now())}.json';

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Salvar Backup Como',
        fileName: fileName,
        bytes: utf8.encode(jsonString),
      );

      if (outputFile == null) {
        if (context.mounted) {
           _showSnackBar(context, 'Exportação cancelada ou falhou.', Colors.grey);
        }
        return null;
      }

      if (context.mounted) {
        final message = includeTrash 
            ? 'Backup completo (com lixeira) exportado com sucesso!'
            : 'Backup dos dados ativos exportado com sucesso!';
        _showSnackBar(context, message, Colors.green);
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

      // ✅ ATUALIZADO: Suporte para versões 1, 2 e 3 do backup
      final version = backupData['version'] ?? 1;
      final includeTrash = backupData['includeTrash'] ?? false;
      
      if (version < 1 || version > 3 || 
          backupData['categories'] == null || 
          backupData['reminders'] == null ||
          backupData['notes'] == null) {
        throw const FormatException('Formato de backup inválido ou não suportado.');
      }

      // ✅ NOVO: Mostrar informações do backup antes de importar
      final confirmed = await _showImportConfirmation(context, version, includeTrash);
      if (!confirmed) return false;

      final categories = (backupData['categories'] as List).cast<Map<String, dynamic>>();
      final reminders = (backupData['reminders'] as List).cast<Map<String, dynamic>>();
      final notes = (backupData['notes'] as List).cast<Map<String, dynamic>>();
      
      // ✅ NOVO: Dados da lixeira (versão 3)
      final deletedReminders = version >= 3 && includeTrash 
          ? (backupData['deletedReminders'] as List?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[]
          : <Map<String, dynamic>>[];
      final deletedNotes = version >= 3 && includeTrash 
          ? (backupData['deletedNotes'] as List?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[]
          : <Map<String, dynamic>>[];

      // Limpando os bancos (apenas dados ativos)
      await _catHelper.deleteAllCategoriesExceptDefault();
      await _dbHelper.deleteAllReminders();
      await _noteHelper.deleteAllNotes();

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

      // ✅ ATUALIZADO: Importando lembretes ativos
      for (final reminderMap in reminders) {
        try {
          // Para backups antigos (versão 1), adicionar createdAt se não existir
          if (version == 1 && reminderMap['createdAt'] == null) {
            reminderMap['createdAt'] = DateTime.now().millisecondsSinceEpoch;
          }
          
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
          debugPrint('Erro ao importar lembrete: $e');
        }
      }

      // ✅ NOVO: Importando lembretes deletados (se houver)
      for (final reminderMap in deletedReminders) {
        try {
          if (version <= 2 && reminderMap['createdAt'] == null) {
            reminderMap['createdAt'] = DateTime.now().millisecondsSinceEpoch;
          }
          
          final reminder = Reminder.fromMap(reminderMap);
          await _dbHelper.insertReminder(reminder);
        } catch (e) {
          debugPrint('Erro ao importar lembrete deletado: $e');
        }
      }

      // Importando anotações ativas
      for (final noteMap in notes) {
        try {
          final noteMapWithoutId = Map<String, dynamic>.from(noteMap);
          noteMapWithoutId.remove('id');
          
          final note = Note.fromMap(noteMapWithoutId);
          await _noteHelper.insertNote(note);
        } catch (e) {
          debugPrint('Erro ao importar anotação: $e');
        }
      }

      // ✅ NOVO: Importando anotações deletadas (se houver)
      for (final noteMap in deletedNotes) {
        try {
          final noteMapWithoutId = Map<String, dynamic>.from(noteMap);
          noteMapWithoutId.remove('id');
          
          final note = Note.fromMap(noteMapWithoutId);
          await _noteHelper.insertNote(note);
        } catch (e) {
          debugPrint('Erro ao importar anotação deletada: $e');
        }
      }

      if (context.mounted) {
        final message = includeTrash 
            ? 'Backup completo (com lixeira) importado com sucesso!'
            : 'Backup importado com sucesso!';
        _showSnackBar(context, message, Colors.green);
      }
      return true;

    } catch (e) {
      if (context.mounted) {
         _showSnackBar(context, 'Erro ao importar backup: ${e.toString()}', Colors.red);
      }
      return false;
    }
  }

  // ✅ NOVO: Diálogo de confirmação com informações do backup
  Future<bool> _showImportConfirmation(BuildContext context, int version, bool includeTrash) async {
    final versionText = version == 1 ? 'v1 (Básico)' 
                      : version == 2 ? 'v2 (com CreatedAt)' 
                      : 'v3 (com Lixeira)';
    
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Importação'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Informações do backup:'),
            const SizedBox(height: 8),
            Text('• Versão: $versionText'),
            Text('• Inclui lixeira: ${includeTrash ? 'Sim' : 'Não'}'),
            const SizedBox(height: 16),
            const Text(
              '⚠️ ATENÇÃO: Esta ação irá:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text('• Substituir todos os dados existentes'),
            const Text('• Limpar a lixeira atual'),
            if (includeTrash) const Text('• Restaurar itens da lixeira do backup'),
            const SizedBox(height: 8),
            const Text('Esta ação não pode ser desfeita!'),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Importar Mesmo Assim'),
          ),
        ],
      ),
    ) ?? false;
  }
}