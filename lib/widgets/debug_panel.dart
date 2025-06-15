// lib/widgets/debug_panel.dart
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/reminder.dart';
import '../utils/test_data.dart';

class DebugPanel extends StatelessWidget {
  const DebugPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _showDebugOptions(context),
      label: const Text('Debug'),
      icon: const Icon(Icons.bug_report),
      backgroundColor: Colors.orange,
    );
  }

  void _showDebugOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Painel de Debug',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            ListTile(
              leading: const Icon(Icons.add_box, color: Colors.green),
              title: const Text('Adicionar Dados de Teste'),
              onTap: () async {
                Navigator.pop(context);
                await _addTestData(context);
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Limpar Todos os Dados'),
              onTap: () async {
                Navigator.pop(context);
                await _clearAllData(context);
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.info, color: Colors.blue),
              title: const Text('Mostrar Estatísticas'),
              onTap: () {
                Navigator.pop(context);
                _showStats(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addTestData(BuildContext context) async {
    try {
      final dbHelper = DatabaseHelper();
      final testReminders = TestData.getSampleReminders();
      
      for (final reminder in testReminders) {
        await dbHelper.insertReminder(reminder);
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dados de teste adicionados com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao adicionar dados: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearAllData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar Dados'),
        content: const Text('Tem certeza? Todos os lembretes e checklists serão removidos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final dbHelper = DatabaseHelper();
        await dbHelper.deleteAllReminders();
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Todos os dados foram removidos!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao limpar dados: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showStats(BuildContext context) async {
    try {
      final dbHelper = DatabaseHelper();
      final allReminders = await dbHelper.getAllReminders();
      
      final normalReminders = allReminders.where((r) => !r.isChecklist).length;
      final checklists = allReminders.where((r) => r.isChecklist).length;
      final completed = allReminders.where((r) => r.isCompleted).length;
      
      int totalChecklistItems = 0;
      int completedChecklistItems = 0;
      
      for (final reminder in allReminders.where((r) => r.isChecklist)) {
        if (reminder.checklistItems != null) {
          totalChecklistItems += reminder.checklistItems!.length;
          completedChecklistItems += reminder.checklistItems!.where((item) => item.isCompleted).length;
        }
      }

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Estatísticas'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📝 Lembretes normais: $normalReminders'),
                Text('📋 Checklists: $checklists'),
                Text('✅ Concluídos: $completed'),
                const SizedBox(height: 10),
                Text('📄 Total de items: $totalChecklistItems'),
                Text('✅ Items concluídos: $completedChecklistItems'),
                if (totalChecklistItems > 0)
                  Text('📊 Progresso: ${((completedChecklistItems / totalChecklistItems) * 100).round()}%'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar estatísticas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}