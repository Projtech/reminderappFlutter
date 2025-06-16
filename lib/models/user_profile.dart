class UserProfile {
  final String? name;
  final String? email;
  final String? photoPath;
  final bool isConfigured;

  const UserProfile({
    this.name,
    this.email,
    this.photoPath,
    this.isConfigured = false,
  });

  // Construtor para perfil vazio (padrão)
  const UserProfile.empty()
      : name = null,
        email = null,
        photoPath = null,
        isConfigured = false;

  // Criar UserProfile a partir de Map (SharedPreferences)
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      name: map['name'] as String?,
      email: map['email'] as String?,
      photoPath: map['photoPath'] as String?,
      isConfigured: map['isConfigured'] as bool? ?? false,
    );
  }

  // Converter UserProfile para Map (SharedPreferences)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'photoPath': photoPath,
      'isConfigured': isConfigured,
    };
  }

  // Criar cópia com alterações
  UserProfile copyWith({
    String? name,
    String? email,
    String? photoPath,
    bool? isConfigured,
  }) {
    return UserProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      photoPath: photoPath ?? this.photoPath,
      isConfigured: isConfigured ?? this.isConfigured,
    );
  }

  // Verificar se tem dados básicos preenchidos
  bool get hasBasicInfo => name != null && name!.trim().isNotEmpty;

  // Verificar se tem foto
  bool get hasPhoto => photoPath != null && photoPath!.isNotEmpty;

  // Nome para exibição (com fallback)
  String get displayName => (name != null && name!.trim().isNotEmpty) 
      ? name!.trim() 
      : 'Usuário';

  @override
  String toString() {
    return 'UserProfile(name: $name, email: $email, photoPath: $photoPath, isConfigured: $isConfigured)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile &&
        other.name == name &&
        other.email == email &&
        other.photoPath == photoPath &&
        other.isConfigured == isConfigured;
  }

  @override
  int get hashCode {
    return name.hashCode ^
        email.hashCode ^
        photoPath.hashCode ^
        isConfigured.hashCode;
  }
}