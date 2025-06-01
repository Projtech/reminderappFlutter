import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart'; // Reativado
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart'; // Importar o DateFormat oficial
import '../database/database_helper.dart';
import '../database/category_helper.dart';
import '../models/reminder.dart';
// Import necessário para NotificationService se não estiver já importado globalmente
import 'notification_service.dart';

class BackupService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final CategoryHelper _catHelper = CategoryHelper();

  // Função auxiliar para mostrar SnackBar (movida para cima para melhor organização)
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

  Future<bool> _requestStoragePermission() async {
    // Para Android 10 (API 29) e superior, o file_picker pode não precisar de permissão explícita
    // para salvar/ler em diretórios públicos via Storage Access Framework.
    // No entanto, para compatibilidade com versões anteriores e acesso a diretórios específicos,
    // manter a verificação com permission_handler é uma boa prática.
    // O FilePicker em si pode solicitar permissões se necessário em algumas plataformas/operações.
    // Vamos verificar a permissão de armazenamento externo.
    // Nota: No Android 13+, as permissões de mídia (fotos, vídeos, áudio) são granulares.
    // Se o backup pudesse conter mídia, permissões mais específicas seriam necessárias.
    // Para um backup JSON, a permissão de armazenamento geral (ou nenhuma em alguns casos) deve bastar.

    // Em versões mais recentes do Android, Permission.storage pode não ser suficiente ou aplicável.
    // Permission.manageExternalStorage é mais abrangente, mas requer declaração especial e justificação.
    // Vamos tentar com storage por enquanto, mas pode precisar de ajuste dependendo da versão do Android alvo.
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }

    // Se ainda não concedida, talvez tentar photos/videos se aplicável, ou informar o usuário.
    if (!status.isGranted) {
       // Poderia tentar Permission.manageExternalStorage, mas é mais complexo.
       // Ou verificar permissões de mídia se o backup incluísse isso.
       debugPrint("Permissão de armazenamento não concedida.");
    }

    return status.isGranted;
  }

  Future<String?> exportBackup(BuildContext context) async {
    // // Removendo a verificação explícita de permissão - FilePicker (SAF) cuida disso.
    // if (!await _requestStoragePermission()) {
    //   _showSnackBar(context, 'Permissão de armazenamento negada.', Colors.red);
    //   return null;
    // }

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

      // Reativando o código do FilePicker para salvar
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Salvar Backup Como',
        fileName: 'lembretes_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json',
        // type: FileType.custom, // saveFile não usa 'type' ou 'allowedExtensions' diretamente como pickFiles
        // allowedExtensions: ['json'], // Use fileName para sugerir a extensão
        bytes: utf8.encode(jsonString), // Passar os bytes diretamente é mais robusto para saveFile
        // lockParentWindow: true, // Opcional: pode melhorar a experiência do usuário em desktop
      );

      if (outputFile == null) {
        // Usuário cancelou ou falhou ao salvar (outputFile será null se não salvar)
        _showSnackBar(context, 'Exportação cancelada ou falhou.', Colors.grey);
        return null;
      }

      // O saveFile já salva o arquivo, não precisamos escrever manualmente com File(outputFile)
      // final file = File(outputFile); // Não necessário se 'bytes' foi passado
      // await file.writeAsString(jsonString); // Não necessário se 'bytes' foi passado

      _showSnackBar(context, 'Backup exportado com sucesso!', Colors.green);
      return outputFile; // Retorna o caminho onde foi salvo (pode ser null se falhar)

    } catch (e) {
      debugPrint('❌ Erro ao exportar backup: $e');
      _showSnackBar(context, 'Erro ao exportar backup: ${e.toString()}', Colors.red);
      return null;
    }
  }

  Future<bool> importBackup(BuildContext context) async {
    try {
      // // Removendo a verificação explícita de permissão - FilePicker (SAF) cuida disso.
      // // Solicitar permissão antes de tentar ler (importante para pickFiles)
      // // A permissão necessária pode variar dependendo da plataforma e versão do Android.
      // // Vamos manter a verificação genérica de storage por enquanto.
      // if (!await _requestStoragePermission()) {
      //    _showSnackBar(context, 'Permissão de leitura de armazenamento negada.', Colors.red);
      //    return false;
      // }

      // Reativando o código do FilePicker para escolher arquivo
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        // lockParentWindow: true, // Opcional
      );

      if (result == null || result.files.single.path == null) {
        // Usuário cancelou ou não selecionou um arquivo válido
        _showSnackBar(context, 'Importação cancelada ou nenhum arquivo selecionado.', Colors.grey);
        return false;
      }

      // Obtendo o caminho do arquivo selecionado
      final filePath = result.files.single.path!;
      final file = File(filePath);

      // Lendo o conteúdo do arquivo
      final jsonString = await file.readAsString();
      // Removendo a linha temporária: final jsonString = "";

      final backupData = jsonDecode(jsonString) as Map<String, dynamic>;

      // Validação básica do formato
      if (backupData['version'] != 1 || backupData['categories'] == null || backupData['reminders'] == null) {
        throw const FormatException('Formato de backup inválido ou não suportado.');
      }

      final categories = (backupData['categories'] as List).cast<Map<String, dynamic>>();
      final reminders = (backupData['reminders'] as List).cast<Map<String, dynamic>>();

      // Limpar dados atuais (exceto categoria 'Geral')
      await _catHelper.deleteAllCategoriesExceptDefault();
      await _dbHelper.deleteAllReminders();

      // Importar categorias
      for (final categoryMap in categories) {
        if (categoryMap['name']?.toLowerCase() != 'geral') {
           // Garantir que 'name' e 'color' não sejam nulos antes de inserir
           final name = categoryMap['name'] as String?;
           final color = categoryMap['color'] as String?;
           if (name != null && color != null) {
             await _catHelper.addCategory(name, color); // Corrigido para addCategory
           } else {
             debugPrint("Categoria inválida no backup (nome ou cor nulos): $categoryMap");
           }
        }
      }

      // Importar lembretes
      for (final reminderMap in reminders) {
        try {
          final reminder = Reminder.fromMap(reminderMap);
          await _dbHelper.insertReminder(reminder);
           // Corrigindo a chamada para usar argumentos nomeados
          await NotificationService.scheduleNotification(
            id: reminder.id!, // Assumindo que id não é nulo após fromMap
            title: reminder.title,
            description: reminder.description,
            scheduledDate: reminder.dateTime,
            category: reminder.category,
          );
        } catch (e) {
           debugPrint("Erro ao importar lembrete individual: $reminderMap - Erro: $e");
           // Pode ser útil notificar o usuário sobre lembretes específicos que falharam
        }
      }

      _showSnackBar(context, 'Backup importado com sucesso!', Colors.green);
      return true;

    } catch (e) {
      debugPrint('❌ Erro ao importar backup: $e');
      _showSnackBar(context, 'Erro ao importar backup: ${e.toString()}', Colors.red);
      return false;
    }
  }
}

