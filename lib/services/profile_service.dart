import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

class ProfileService {
  static const String _profileKey = 'user_profile';
  
  // Singleton
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  SharedPreferences? _prefs;

  // Inicializar SharedPreferences
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Garantir que está inicializado
  Future<SharedPreferences> get prefs async {
    if (_prefs == null) {
      await init();
    }
    return _prefs!;
  }

  // Carregar perfil do usuário
  Future<UserProfile> loadProfile() async {
    try {
      final preferences = await prefs;
      final profileJson = preferences.getString(_profileKey);
      
      if (profileJson == null || profileJson.isEmpty) {
        return const UserProfile.empty();
      }

      final profileMap = jsonDecode(profileJson) as Map<String, dynamic>;
      return UserProfile.fromMap(profileMap);
    } catch (e) {
      // Em caso de erro, retorna perfil vazio
      return const UserProfile.empty();
    }
  }

  // Salvar perfil do usuário
  Future<bool> saveProfile(UserProfile profile) async {
    try {
      final preferences = await prefs;
      final profileJson = jsonEncode(profile.toMap());
      return await preferences.setString(_profileKey, profileJson);
    } catch (e) {
      return false;
    }
  }

  // Atualizar nome
  Future<bool> updateName(String? name) async {
    final currentProfile = await loadProfile();
    final updatedProfile = currentProfile.copyWith(
      name: name,
      isConfigured: true,
    );
    return await saveProfile(updatedProfile);
  }

  // Atualizar email
  Future<bool> updateEmail(String? email) async {
    final currentProfile = await loadProfile();
    final updatedProfile = currentProfile.copyWith(
      email: email,
      isConfigured: true,
    );
    return await saveProfile(updatedProfile);
  }

  // Atualizar foto
  Future<bool> updatePhoto(String? photoPath) async {
    final currentProfile = await loadProfile();
    final updatedProfile = currentProfile.copyWith(
      photoPath: photoPath,
      isConfigured: true,
    );
    return await saveProfile(updatedProfile);
  }

  // Limpar perfil (resetar)
  Future<bool> clearProfile() async {
    try {
      final preferences = await prefs;
      return await preferences.remove(_profileKey);
    } catch (e) {
      return false;
    }
  }

  // Verificar se perfil existe
  Future<bool> hasProfile() async {
    final profile = await loadProfile();
    return profile.isConfigured;
  }

  // Verificar se tem dados básicos
  Future<bool> hasBasicInfo() async {
    final profile = await loadProfile();
    return profile.hasBasicInfo;
  }
}