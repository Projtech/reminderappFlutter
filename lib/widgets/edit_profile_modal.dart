import 'dart:io';
import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';
import '../services/image_service.dart';

class EditProfileModal extends StatefulWidget {
  final UserProfile currentProfile;
  final Function(UserProfile)? onProfileUpdated;

  const EditProfileModal({
    super.key,
    required this.currentProfile,
    this.onProfileUpdated,
  });

  static Future<UserProfile?> show(
    BuildContext context, {
    required UserProfile currentProfile,
    Function(UserProfile)? onProfileUpdated,
  }) async {
    return await showModalBottomSheet<UserProfile>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditProfileModal(
        currentProfile: currentProfile,
        onProfileUpdated: onProfileUpdated,
      ),
    );
  }

  @override
  State<EditProfileModal> createState() => _EditProfileModalState();
}

class _EditProfileModalState extends State<EditProfileModal> {
  final ProfileService _profileService = ProfileService();
  final ImageService _imageService = ImageService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  
  String? _currentPhotoPath;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.currentProfile.name ?? '';
    _emailController.text = widget.currentProfile.email ?? '';
    _currentPhotoPath = widget.currentProfile.photoPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle do modal
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // Título
                Text(
                  'Editar Perfil',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),

                // Foto de perfil
                _buildPhotoSection(),
                const SizedBox(height: 30),

                // Campo Nome
                _buildTextField(
                  controller: _nameController,
                  label: 'Nome',
                  hint: 'Digite seu nome',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 20),

                // Campo Email
                _buildTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'Digite seu email (opcional)',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 40),

                // Botões
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveProfile,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Salvar'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      children: [
        GestureDetector(
          onTap: _isLoading ? null : _changePhoto,
          child: Stack(
            children: [
              _imageService.getProfileImage(_currentPhotoPath, size: 100),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Toque para alterar foto',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        if (_currentPhotoPath != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isLoading ? null : _removePhoto,
            child: Text(
              'Remover foto',
              style: TextStyle(color: Colors.red[400]),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        enabled: !_isLoading,
      ),
    );
  }

  Future<void> _changePhoto() async {
    final newPhotoPath = await _imageService.pickImage(context);
    if (newPhotoPath != null) {
      setState(() {
        _currentPhotoPath = newPhotoPath;
      });
    }
  }

  void _removePhoto() {
    setState(() {
      _currentPhotoPath = null;
    });
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);

    try {
      // Deletar foto antiga se foi removida
      if (widget.currentProfile.photoPath != null && _currentPhotoPath == null) {
        await _imageService.deleteImage(widget.currentProfile.photoPath);
      }

      // Criar novo perfil
      final newProfile = UserProfile(
        name: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        photoPath: _currentPhotoPath,
        isConfigured: true,
      );

      // Salvar
      final success = await _profileService.saveProfile(newProfile);

      if (success) {
        if (widget.onProfileUpdated != null) {
          widget.onProfileUpdated!(newProfile);
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Perfil atualizado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, newProfile);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao salvar perfil'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro inesperado ao salvar perfil'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}