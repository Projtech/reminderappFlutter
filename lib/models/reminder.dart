// lib/models/reminder.dart - PARTE 1
import 'dart:convert';
import 'checklist_item.dart';

class Reminder {
  int? id;
  String title;
  String description;
  String category;
  DateTime dateTime;
  DateTime createdAt;
  bool isCompleted;
  bool isRecurring;
  String? recurringType; // none, daily, weekly, monthly, custom_daily, custom_weekly, custom_monthly
  int recurrenceInterval; // Para custom: "a cada X dias/semanas/meses"
  bool notificationsEnabled;
  bool deleted; // ✅ NOVO: Campo da lixeira
  DateTime? deletedAt; // ✅ NOVO: Quando foi deletado
  bool isChecklist; // ✅ NOVO: Se é um checklist
  List<ChecklistItem>? checklistItems; // ✅ NOVO: Items do checklist

  Reminder({
    this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.dateTime,
    DateTime? createdAt,
    this.isCompleted = false,
    this.isRecurring = false,
    this.recurringType,
    this.recurrenceInterval = 1,
    this.notificationsEnabled = true,
    this.deleted = false, // ✅ NOVO: Padrão não deletado
    this.deletedAt, // ✅ NOVO: Nullable
    this.isChecklist = false, // ✅ NOVO: Padrão não é checklist
    this.checklistItems, // ✅ NOVO: Lista de items
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'dateTime': dateTime.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'isCompleted': isCompleted ? 1 : 0,
      'isRecurring': isRecurring ? 1 : 0,
      'recurringType': recurringType,
      'recurrenceInterval': recurrenceInterval,
      'notificationsEnabled': notificationsEnabled ? 1 : 0,
      'deleted': deleted ? 1 : 0, // ✅ NOVO
      'deletedAt': deletedAt?.millisecondsSinceEpoch, // ✅ NOVO
      'isChecklist': isChecklist ? 1 : 0, // ✅ NOVO
      'checklistItems': checklistItems != null // ✅ NOVO
          ? jsonEncode(checklistItems!.map((item) => item.toMap()).toList())
          : null,
    };
  }
  // lib/models/reminder.dart - PARTE 2 (continuação)

 factory Reminder.fromMap(Map<String, dynamic> map) {
   // ✅ NOVO: Parsing dos checklistItems
   List<ChecklistItem>? items;
   if (map['checklistItems'] != null && map['checklistItems'].toString().isNotEmpty) {
     try {
       final List<dynamic> itemsList = jsonDecode(map['checklistItems']);
       items = itemsList.map((item) => ChecklistItem.fromMap(item as Map<String, dynamic>)).toList();
     } catch (e) {
       items = null; // Se der erro no parsing, mantém como null
     }
   }

   return Reminder(
     id: map['id'],
     title: map['title'],
     description: map['description'],
     category: map['category'],
     dateTime: DateTime.fromMillisecondsSinceEpoch(map['dateTime']),
     createdAt: map['createdAt'] != null 
         ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
         : DateTime.now(),
     isCompleted: map['isCompleted'] == 1,
     isRecurring: (map['isRecurring'] ?? 0) == 1,
     recurringType: map['recurringType'],
     recurrenceInterval: map['recurrenceInterval'] ?? 1,
     notificationsEnabled: (map['notificationsEnabled'] ?? 1) == 1,
     deleted: (map['deleted'] ?? 0) == 1, // ✅ NOVO: Com fallback
     deletedAt: map['deletedAt'] != null // ✅ NOVO: Com fallback
         ? DateTime.fromMillisecondsSinceEpoch(map['deletedAt'])
         : null,
     isChecklist: (map['isChecklist'] ?? 0) == 1, // ✅ NOVO
     checklistItems: items, // ✅ NOVO
   );
 }

 Reminder copyWith({
   int? id,
   String? title,
   String? description,
   String? category,
   DateTime? dateTime,
   DateTime? createdAt,
   bool? isCompleted,
   bool? isRecurring,
   String? recurringType,
   int? recurrenceInterval,
   bool? notificationsEnabled,
   bool? deleted, // ✅ NOVO
   DateTime? deletedAt, // ✅ NOVO
   bool? isChecklist, // ✅ NOVO
   List<ChecklistItem>? checklistItems, // ✅ NOVO
 }) {
   return Reminder(
     id: id ?? this.id,
     title: title ?? this.title,
     description: description ?? this.description,
     category: category ?? this.category,
     dateTime: dateTime ?? this.dateTime,
     createdAt: createdAt ?? this.createdAt,
     isCompleted: isCompleted ?? this.isCompleted,
     isRecurring: isRecurring ?? this.isRecurring,
     recurringType: recurringType ?? this.recurringType,
     recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
     notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
     deleted: deleted ?? this.deleted, // ✅ NOVO
     deletedAt: deletedAt ?? this.deletedAt, // ✅ NOVO
     isChecklist: isChecklist ?? this.isChecklist, // ✅ NOVO
     checklistItems: checklistItems ?? this.checklistItems, // ✅ NOVO
   );
 }

 // ✅ NOVO: Métodos para checklist
 int get completedItemsCount {
   if (!isChecklist || checklistItems == null) return 0;
   return checklistItems!.where((item) => item.isCompleted).length;
 }

 int get totalItemsCount {
   if (!isChecklist || checklistItems == null) return 0;
   return checklistItems!.length;
 }

 double get completionPercentage {
   if (!isChecklist || checklistItems == null || checklistItems!.isEmpty) return 0.0;
   return completedItemsCount / totalItemsCount;
 }

 String get checklistProgress {
   if (!isChecklist) return '';
   return '$completedItemsCount/$totalItemsCount';
 }

 List<ChecklistItem> get pendingItems {
   if (!isChecklist || checklistItems == null) return [];
   return checklistItems!.where((item) => !item.isCompleted).toList();
 }

 String get nextItemsPreview {
   if (!isChecklist || checklistItems == null) return '';
   final pending = pendingItems.take(3).map((item) => item.text).toList();
   if (pending.isEmpty) return 'Tudo concluído!';
   if (pending.length <= 2) return pending.join(', ');
   return '${pending.take(2).join(', ')}...';
 }

 // ✅ NOVO: Marcar como deletado
 Reminder markAsDeleted() {
   return copyWith(
     deleted: true,
     deletedAt: DateTime.now(),
   );
 }

 // ✅ NOVO: Restaurar da lixeira
 Reminder restore() {
   return copyWith(
     deleted: false,
     deletedAt: null,
   );
 }

 // ✅ RESTO DO CÓDIGO PERMANECE IGUAL (todos os métodos de repetição)
 DateTime getNextOccurrence() {
   if (!isRecurring || recurringType == null || recurringType == 'none') {
     return dateTime;
   }

   final now = DateTime.now();
   var nextDate = DateTime(dateTime.year, dateTime.month, dateTime.day, dateTime.hour, dateTime.minute);

   // Se a data original já passou, começamos calculando a partir de agora
   if (nextDate.isBefore(now)) {
     switch (recurringType!) {
       case 'daily':
         return _getNextDaily(now);
       case 'weekly':
         return _getNextWeekly(now);
       case 'monthly':
         return _getNextMonthly(now);
       case 'custom_daily':
         return _getNextCustomDaily(now);
       case 'custom_weekly':
         return _getNextCustomWeekly(now);
       case 'custom_monthly':
         return _getNextCustomMonthly(now);
       default:
         return nextDate;
     }
   }

   return nextDate;
 }

 // ✅ GERAR MÚLTIPLAS OCORRÊNCIAS (para agendar de uma vez)
 List<DateTime> getNextOccurrences(int count) {
   if (!isRecurring || recurringType == null || recurringType == 'none') {
     return [dateTime];
   }

   final List<DateTime> occurrences = [];
   var current = getNextOccurrence();

   for (int i = 0; i < count; i++) {
     occurrences.add(current);
     current = _getNextOccurrenceFrom(current);
   }

   return occurrences;
 }

 DateTime _getNextOccurrenceFrom(DateTime from) {
   switch (recurringType!) {
     case 'daily':
       return from.add(const Duration(days: 1));
     case 'weekly':
       return from.add(const Duration(days: 7));
     case 'monthly':
       return _addMonthsSafe(from, 1);
     case 'custom_daily':
       return from.add(Duration(days: recurrenceInterval));
     case 'custom_weekly':
       return from.add(Duration(days: 7 * recurrenceInterval));
     case 'custom_monthly':
       return _addMonthsSafe(from, recurrenceInterval);
     default:
       return from;
   }
 }

 DateTime _getNextDaily(DateTime now) {
   final todayAtTime = DateTime(now.year, now.month, now.day, dateTime.hour, dateTime.minute);
   if (todayAtTime.isAfter(now)) {
     return todayAtTime;
   }
   return todayAtTime.add(const Duration(days: 1));
 }

 DateTime _getNextWeekly(DateTime now) {
   final targetWeekday = dateTime.weekday;
   var current = DateTime(now.year, now.month, now.day, dateTime.hour, dateTime.minute);
   
   // Ajustar para o dia da semana correto
   int daysToAdd = (targetWeekday - current.weekday) % 7;
   if (daysToAdd == 0 && current.isBefore(now)) {
     daysToAdd = 7; // Próxima semana
   }
   
   return current.add(Duration(days: daysToAdd));
 }

 DateTime _getNextMonthly(DateTime now) {
   var current = DateTime(now.year, now.month, dateTime.day, dateTime.hour, dateTime.minute);
   
   // Se este mês já passou, vai para o próximo
   if (current.isBefore(now)) {
     current = _addMonthsSafe(current, 1);
   }
   
   return current;
 }

 DateTime _getNextCustomDaily(DateTime now) {
   final todayAtTime = DateTime(now.year, now.month, now.day, dateTime.hour, dateTime.minute);
   if (todayAtTime.isAfter(now)) {
     return todayAtTime;
   }
   
   // Calcular quantos intervalos precisamos pular
   final daysSinceOriginal = now.difference(dateTime).inDays;
   final intervalsPassed = (daysSinceOriginal / recurrenceInterval).floor();
   final nextInterval = intervalsPassed + 1;
   
   return dateTime.add(Duration(days: nextInterval * recurrenceInterval));
 }

 DateTime _getNextCustomWeekly(DateTime now) {
   final targetWeekday = dateTime.weekday;
   var baseDate = DateTime(now.year, now.month, now.day, dateTime.hour, dateTime.minute);
   
   // Ajustar para o dia da semana correto desta semana
   int daysToAdd = (targetWeekday - baseDate.weekday) % 7;
   var thisWeekTarget = baseDate.add(Duration(days: daysToAdd));
   
   if (thisWeekTarget.isAfter(now)) {
     return thisWeekTarget;
   }
   
   // Calcular quantas semanas precisamos pular
   final weeksSinceOriginal = now.difference(dateTime).inDays ~/ 7;
   final intervalsPassed = (weeksSinceOriginal / recurrenceInterval).floor();
   final nextInterval = intervalsPassed + 1;
   
   return dateTime.add(Duration(days: nextInterval * recurrenceInterval * 7));
 }

 DateTime _getNextCustomMonthly(DateTime now) {
   var current = DateTime(now.year, now.month, dateTime.day, dateTime.hour, dateTime.minute);
   
   if (current.isAfter(now)) {
     return current;
   }
   
   // Adicionar intervalos até estar no futuro
   while (current.isBefore(now)) {
     current = _addMonthsSafe(current, recurrenceInterval);
   }
   
   return current;
 }

 // ✅ ADICIONAR MESES DE FORMA SEGURA (lida com 31 jan + 1 mês = 28 fev)
 DateTime _addMonthsSafe(DateTime date, int months) {
   int newYear = date.year;
   int newMonth = date.month + months;
   
   while (newMonth > 12) {
     newYear++;
     newMonth -= 12;
   }
   
   // Ajustar dia se o mês de destino não tem esse dia
   int newDay = date.day;
   int daysInNewMonth = DateTime(newYear, newMonth + 1, 0).day;
   if (newDay > daysInNewMonth) {
     newDay = daysInNewMonth; // Último dia do mês
   }
   
   return DateTime(newYear, newMonth, newDay, date.hour, date.minute);
 }

 // ✅ DESCRIÇÃO HUMANA DA REPETIÇÃO
 String getRecurrenceDescription() {
   if (!isRecurring || recurringType == null || recurringType == 'none') {
     return 'Não repetir';
   }
   
   switch (recurringType!) {
     case 'daily':
       return 'Diariamente';
     case 'weekly':
       return 'Semanalmente';
     case 'monthly':
       return 'Mensalmente';
     case 'custom_daily':
       return recurrenceInterval == 1 ? 'Diariamente' : 'A cada $recurrenceInterval dias';
     case 'custom_weekly':
       return recurrenceInterval == 1 ? 'Semanalmente' : 'A cada $recurrenceInterval semanas';
     case 'custom_monthly':
       return recurrenceInterval == 1 ? 'Mensalmente' : 'A cada $recurrenceInterval meses';
     default:
       return 'Personalizado';
   }
 }
}