// lib/utils/test_data.dart
import '../models/reminder.dart';
import '../models/checklist_item.dart';

class TestData {
  static List<Reminder> getSampleReminders() {
    return [
      // Lembrete normal
      Reminder(
        id: 1,
        title: 'Reunião com cliente',
        description: 'Apresentar proposta do projeto',
        category: 'trabalho',
        dateTime: DateTime.now().add(const Duration(hours: 2)),
        isChecklist: false,
      ),
      
      // Checklist de compras
      Reminder(
        id: 2,
        title: 'Lista de Compras',
        description: '',
        category: 'casa',
        dateTime: DateTime.now().add(const Duration(hours: 1)),
        isChecklist: true,
        checklistItems: [
          ChecklistItem(text: 'Pão integral', order: 0, isCompleted: true),
          ChecklistItem(text: 'Leite desnatado', order: 1, isCompleted: true),
          ChecklistItem(text: 'Ovos', order: 2, isCompleted: true),
          ChecklistItem(text: 'Queijo minas', order: 3, isCompleted: false),
          ChecklistItem(text: 'Presunto', order: 4, isCompleted: false),
          ChecklistItem(text: 'Iogurte natural', order: 5, isCompleted: false),
          ChecklistItem(text: 'Frutas (banana/maçã)', order: 6, isCompleted: false),
        ],
      ),
      
      // Checklist de estudos
      Reminder(
        id: 3,
        title: 'Preparação para Prova',
        description: '',
        category: 'estudos',
        dateTime: DateTime.now().add(const Duration(days: 1)),
        isChecklist: true,
        checklistItems: [
          ChecklistItem(text: 'Ler capítulo 1', order: 0, isCompleted: true),
          ChecklistItem(text: 'Fazer exercícios página 50', order: 1, isCompleted: true),
          ChecklistItem(text: 'Revisar anotações', order: 2, isCompleted: false),
          ChecklistItem(text: 'Fazer resumo', order: 3, isCompleted: false),
          ChecklistItem(text: 'Praticar questões', order: 4, isCompleted: false),
        ],
      ),
      
      // Lembrete normal
      Reminder(
        id: 4,
        title: 'Consulta médica',
        description: 'Checkup anual - Dr. Silva',
        category: 'saúde',
        dateTime: DateTime.now().add(const Duration(days: 2)),
        isChecklist: false,
      ),
      
      // Checklist de viagem
      Reminder(
        id: 5,
        title: 'Preparar Viagem',
        description: '',
        category: 'pessoal',
        dateTime: DateTime.now().add(const Duration(days: 7)),
        isChecklist: true,
        checklistItems: [
          ChecklistItem(text: 'Reservar hotel', order: 0, isCompleted: false),
          ChecklistItem(text: 'Comprar passagens', order: 1, isCompleted: false),
          ChecklistItem(text: 'Fazer as malas', order: 2, isCompleted: false),
          ChecklistItem(text: 'Confirmar documentos', order: 3, isCompleted: false),
        ],
      ),
    ];
  }
  
  static Future<void> insertSampleData() async {
    // TODO: Implementar inserção de dados de teste no banco
    // Isso é opcional, apenas para testes
  }
}