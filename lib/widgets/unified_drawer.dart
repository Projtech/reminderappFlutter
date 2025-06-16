import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';
import '../services/image_service.dart';
import '../widgets/edit_profile_modal.dart';
import '../screens/manage_categories_screen.dart';
import '../screens/reminders_trash_screen.dart';
import '../screens/notes_trash_screen.dart';
import '../services/notification_service.dart';
import '../services/backup_service.dart';
import '../main.dart';

class UnifiedDrawer extends StatefulWidget {
  final String currentScreen;

  const UnifiedDrawer({
    super.key,
    required this.currentScreen,
  });

  @override
  State<UnifiedDrawer> createState() => _UnifiedDrawerState();
}

class _UnifiedDrawerState extends State<UnifiedDrawer> {
  final ProfileService _profileService = ProfileService();
  final ImageService _imageService = ImageService();
  final BackupService _backupService = BackupService();

  UserProfile _currentProfile = const UserProfile.empty();
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoadingProfile = true);
    try {
      final profile = await _profileService.loadProfile();
      if (mounted) {
        setState(() {
          _currentProfile = profile;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildProfileHeader(isDark),
          _buildHomeItem(),
          _buildTrashItem(),
          _buildThemeItem(isDark),
          const Divider(),
          _buildBackupSection(isDark),
          const Divider(),
          if (widget.currentScreen == 'reminders')
            ..._buildRemindersSpecificItems(),
          _buildAboutItem(),
          _buildPrivacyItem(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(bool isDark) {
    return DrawerHeader(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.blue,
      ),
      child: _isLoadingProfile
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _imageService.getProfileImage(_currentProfile.photoPath,
                        size: 60),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentProfile.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_currentProfile.email != null &&
                              _currentProfile.email!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              _currentProfile.email!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ] else ...[
                            const SizedBox(height: 4),
                            Text(
                              _currentProfile.isConfigured
                                  ? ''
                                  : 'Toque para configurar',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _editProfile,
                    icon: Icon(
                      _currentProfile.isConfigured ? Icons.edit : Icons.add,
                      color: Colors.white,
                      size: 16,
                    ),
                    label: Text(
                      _currentProfile.isConfigured ? 'Editar' : 'Adicionar',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHomeItem() {
    return ListTile(
      leading: const Icon(Icons.home),
      title: const Text('Início'),
      onTap: () {
        Navigator.pop(context);
        Navigator.popUntil(context, (route) => route.isFirst);
      },
    );
  }

  Widget _buildTrashItem() {
    if (widget.currentScreen == 'reminders') {
      return ListTile(
        leading: const Icon(Icons.delete_outline),
        title: const Text('Lixeira de Lembretes'),
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const RemindersTrashScreen()),
          );
        },
      );
    } else {
      return ListTile(
        leading: const Icon(Icons.delete_outline),
        title: const Text('Lixeira de Anotações'),
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NotesTrashScreen()),
          );
        },
      );
    }
  }

  Widget _buildThemeItem(bool isDark) {
    return ListTile(
      leading: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
      title: Text(isDark ? 'Modo Claro' : 'Modo Escuro'),
      trailing: Switch(
        value: isDark,
        onChanged: (value) {
          MyApp.of(context)
              ?.changeTheme(value ? ThemeMode.dark : ThemeMode.light);
        },
      ),
      onTap: () {
        final newMode = isDark ? ThemeMode.light : ThemeMode.dark;
        MyApp.of(context)?.changeTheme(newMode);
      },
    );
  }

  Widget _buildBackupSection(bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'BACKUP',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.file_upload),
          title: const Text('Exportar Backup'),
          onTap: () {
            Navigator.pop(context);
            _exportBackup();
          },
        ),
        ListTile(
          leading: const Icon(Icons.file_download),
          title: const Text('Importar Backup'),
          onTap: () {
            // ✅ NÃO FECHAR O DRAWER ANTES DA IMPORTAÇÃO
            _importBackup();
          },
        ),
      ],
    );
  }

  List<Widget> _buildRemindersSpecificItems() {
    return [
      ListTile(
        leading: const Icon(Icons.category),
        title: const Text('Gerenciar Categorias'),
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const ManageCategoriesScreen()),
          );
        },
      ),
      ListTile(
        leading: const Icon(Icons.battery_saver),
        title: const Text('Desativar otimização de bateria'),
        subtitle: const Text('Desabilitar otimização de bateria'),
        onTap: () async {
          Navigator.pop(context);
          await NotificationService.requestBatteryOptimizationDisable();
        },
      ),
      const Divider(),
    ];
  }

  Widget _buildAboutItem() {
    return ListTile(
      leading: const Icon(Icons.info_outline),
      title: const Text('Sobre & Apoiar'),
      onTap: () {
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Em breve: Tela Sobre & Apoiar')),
        );
      },
    );
  }

  Widget _buildPrivacyItem() {
    return ListTile(
      leading: const Icon(Icons.privacy_tip_outlined),
      title: const Text('Privacidade'),
      onTap: () {
        Navigator.pop(context);
        // TODO: Implementar tela de Privacidade
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Em breve: Política de Privacidade')),
        );
      },
    );
  }

  Future<void> _editProfile() async {
    final updatedProfile = await EditProfileModal.show(
      context,
      currentProfile: _currentProfile,
      onProfileUpdated: (profile) {
        setState(() {
          _currentProfile = profile;
        });
      },
    );

    if (updatedProfile != null) {
      setState(() {
        _currentProfile = updatedProfile;
      });
    }
  }

  Future<void> _exportBackup() async {
    try {
      await _backupService.exportBackup(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro inesperado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importBackup() async {
    try {
      // ✅ FECHAR O DRAWER APENAS APÓS A IMPORTAÇÃO
      final success = await _backupService.importBackup(context);
      
      // ✅ SE DEU CERTO, FECHAR O DRAWER
      if (success && mounted) {
        Navigator.pop(context);
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}