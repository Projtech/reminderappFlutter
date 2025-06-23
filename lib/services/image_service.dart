// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;

class ImageService {
  static final ImageService _instance = ImageService._internal();
  factory ImageService() => _instance;
  ImageService._internal();

  final ImagePicker _picker = ImagePicker();

  // Mostrar opções de seleção de imagem
  Future<String?> pickImage(BuildContext context) async {
    return await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Escolher Foto',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Câmera'),
              onTap: () async {
                Navigator.pop(context);
                final imagePath = await pickFromCamera(); // 👈 AGORA PÚBLICO
                Navigator.pop(context, imagePath);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeria'),
              onTap: () async {
                Navigator.pop(context);
                final imagePath = await pickFromGallery(); // 👈 AGORA PÚBLICO
                Navigator.pop(context, imagePath);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Cancelar'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  // 👈 REMOVIDO UNDERSCORE - AGORA PÚBLICO
  Future<String?> pickFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (image != null) {
        return await _processAndSaveImage(image.path);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // 👈 REMOVIDO UNDERSCORE - AGORA PÚBLICO
  Future<String?> pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (image != null) {
        return await _processAndSaveImage(image.path);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Processar e salvar imagem
  Future<String?> _processAndSaveImage(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      final Uint8List imageBytes = await imageFile.readAsBytes();
      
      // Redimensionar imagem
      final img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) return null;

      // Redimensionar para 200x200 mantendo proporção
      final img.Image resizedImage = img.copyResize(
        originalImage,
        width: 200,
        height: 200,
        interpolation: img.Interpolation.average,
      );

      // Salvar no diretório do app
      final String fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String savedPath = await _saveImageToAppDirectory(resizedImage, fileName);
      
      return savedPath;
    } catch (e) {
      return null;
    }
  }

  // Salvar imagem no diretório do app
  Future<String> _saveImageToAppDirectory(img.Image image, String fileName) async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final String profileDir = path.join(appDir.path, 'profile_images');
    
    // Criar diretório se não existir
    final Directory dir = Directory(profileDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Salvar arquivo
    final String filePath = path.join(profileDir, fileName);
    final File file = File(filePath);
    final Uint8List imageBytes = Uint8List.fromList(img.encodeJpg(image, quality: 90));
    await file.writeAsBytes(imageBytes);

    return filePath;
  }

  // Deletar foto antiga
  Future<bool> deleteImage(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return true;
    
    try {
      final File file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  // Verificar se arquivo de imagem existe
  Future<bool> imageExists(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return false;
    
    try {
      final File file = File(imagePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  // Obter widget de imagem para exibição
  Widget getProfileImage(String? imagePath, {double size = 60}) {
    if (imagePath == null || imagePath.isEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.grey[300],
        child: Icon(
          Icons.person,
          size: size * 0.6,
          color: Colors.grey[600],
        ),
      );
    }

    return CircleAvatar(
      radius: size / 2,
      backgroundImage: FileImage(File(imagePath)),
      onBackgroundImageError: (exception, stackTrace) {
        // Em caso de erro, mostra ícone padrão
      },
      child: null,
    );
  }
}