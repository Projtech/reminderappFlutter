// lib/models/checklist_item.dart
class ChecklistItem {
  int? id;
  String text;
  bool isCompleted;
  int order;
  DateTime createdAt;

  ChecklistItem({
    this.id,
    required this.text,
    this.isCompleted = false,
    required this.order,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'isCompleted': isCompleted ? 1 : 0,
      'order': order,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory ChecklistItem.fromMap(Map<String, dynamic> map) {
    return ChecklistItem(
      id: map['id'],
      text: map['text'] ?? '',
      isCompleted: (map['isCompleted'] ?? 0) == 1,
      order: map['order'] ?? 0,
      createdAt: map['createdAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
    );
  }

  ChecklistItem copyWith({
    int? id,
    String? text,
    bool? isCompleted,
    int? order,
    DateTime? createdAt,
  }) {
    return ChecklistItem(
      id: id ?? this.id,
      text: text ?? this.text,
      isCompleted: isCompleted ?? this.isCompleted,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'ChecklistItem{id: $id, text: $text, isCompleted: $isCompleted, order: $order}';
  }
}