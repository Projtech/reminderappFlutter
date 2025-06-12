class Note {
  int? id;
  String title;
  String content;
  bool isPinned;
  DateTime createdAt;
  bool deleted; // ✅ NOVO: Campo da lixeira
  DateTime? deletedAt; // ✅ NOVO: Quando foi deletado

  Note({
    this.id,
    required this.title,
    required this.content,
    this.isPinned = false,
    required this.createdAt,
    this.deleted = false, // ✅ NOVO: Padrão não deletado
    this.deletedAt, // ✅ NOVO: Nullable
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'isPinned': isPinned ? 1 : 0,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'deleted': deleted ? 1 : 0, // ✅ NOVO
      'deletedAt': deletedAt?.millisecondsSinceEpoch, // ✅ NOVO
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      isPinned: (map['isPinned'] ?? 0) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      deleted: (map['deleted'] ?? 0) == 1, // ✅ NOVO: Com fallback
      deletedAt: map['deletedAt'] != null // ✅ NOVO: Com fallback
          ? DateTime.fromMillisecondsSinceEpoch(map['deletedAt'])
          : null,
    );
  }

  Note copyWith({
    int? id,
    String? title,
    String? content,
    bool? isPinned,
    DateTime? createdAt,
    bool? deleted, // ✅ NOVO
    DateTime? deletedAt, // ✅ NOVO
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      deleted: deleted ?? this.deleted, // ✅ NOVO
      deletedAt: deletedAt ?? this.deletedAt, // ✅ NOVO
    );
  }

  // ✅ NOVO: Marcar como deletado
  Note markAsDeleted() {
    return copyWith(
      deleted: true,
      deletedAt: DateTime.now(),
    );
  }

  // ✅ NOVO: Restaurar da lixeira
  Note restore() {
    return copyWith(
      deleted: false,
      deletedAt: null,
    );
  }

  // Método para obter preview do conteúdo
  String get contentPreview {
    if (content.length <= 100) return content;
    return '${content.substring(0, 100)}...';
  }
}