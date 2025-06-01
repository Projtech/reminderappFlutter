class Reminder {
  int? id;
  String title;
  String description;
  String category;
  DateTime dateTime;
  bool isCompleted;
  bool isRecurring;
  String? recurringType;
  bool notificationsEnabled;

  Reminder({
    this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.dateTime,
    this.isCompleted = false,
    this.isRecurring = false,
    this.recurringType,
    this.notificationsEnabled = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'dateTime': dateTime.millisecondsSinceEpoch,
      'isCompleted': isCompleted ? 1 : 0,
      'isRecurring': isRecurring ? 1 : 0,
      'recurringType': recurringType,
      'notificationsEnabled': notificationsEnabled ? 1 : 0,
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      category: map['category'],
      dateTime: DateTime.fromMillisecondsSinceEpoch(map['dateTime']),
      isCompleted: map['isCompleted'] == 1,
      isRecurring: (map['isRecurring'] ?? 0) == 1,
      recurringType: map['recurringType'],
      notificationsEnabled: (map['notificationsEnabled'] ?? 1) == 1,
    );
  }

  // ✅ CORREÇÃO: Adicionado método copyWith
  Reminder copyWith({
    int? id,
    String? title,
    String? description,
    String? category,
    DateTime? dateTime,
    bool? isCompleted,
    bool? isRecurring,
    String? recurringType,
    bool? notificationsEnabled,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      dateTime: dateTime ?? this.dateTime,
      isCompleted: isCompleted ?? this.isCompleted,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringType: recurringType ?? this.recurringType,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }

  DateTime getNextOccurrence() {
    if (!isRecurring || recurringType != 'monthly') return dateTime;

    final now = DateTime.now();
    var nextDate = DateTime(dateTime.year, dateTime.month, dateTime.day, dateTime.hour, dateTime.minute);

    while (nextDate.isBefore(now)) {
      // Avança para o próximo mês, mantendo o dia (cuidado com meses de tamanhos diferentes)
      // Uma lógica mais robusta seria necessária para dias como 31 em meses sem 31 dias.
      // Simplificação: apenas adiciona um mês.
      nextDate = DateTime(nextDate.year, nextDate.month + 1, nextDate.day, nextDate.hour, nextDate.minute);
    }

    return nextDate;
  }
}

