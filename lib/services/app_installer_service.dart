import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'update_service.dart';

class AppInstallerService {
  static bool _isDownloading = false;
  static double _downloadProgress = 0.0;

  // Iniciar processo de atualização
  static Future<void> startUpdate(BuildContext context) async {
    if (_isDownloading) {
      _showSnackBar(context, '📦 Download já em andamento...', Colors.orange);
      return;
    }

    try {
      // Buscar informações da atualização
      final updateInfo = await UpdateService.fetchLatestVersion();
      if (updateInfo == null) {
        _showSnackBar(context, '❌ Erro ao obter informações da atualização', Colors.red);
        return;
      }

      final apkUrl = updateInfo['download']?['apkUrl'] as String?;
      final fileSize = updateInfo['download']?['fileSize'] as String?;
      
      if (apkUrl == null) {
        _showSnackBar(context, '❌ URL de download não encontrada', Colors.red);
        return;
      }

      // Confirmar download
      final shouldDownload = await _showDownloadConfirmation(context, fileSize ?? 'Desconhecido');
      if (!shouldDownload) return;

      // Verificar permissões
      final hasPermissions = await _checkPermissions(context);
      if (!hasPermissions) return;

      // Iniciar download
      await _downloadAndInstallAPK(context, apkUrl);

    } catch (e) {
      _showSnackBar(context, '❌ Erro: ${e.toString()}', Colors.red);
    }
  }

  // Confirmar download
  static Future<bool> _showDownloadConfirmation(BuildContext context, String fileSize) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('💾 Baixar atualização?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Isso irá baixar e instalar a nova versão do app.'),
            const SizedBox(height: 8),
            Text('📦 Tamanho: $fileSize'),
            const SizedBox(height: 8),
            const Text(
              '⚠️ Será necessário permitir instalação de fontes desconhecidas.',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Baixar'),
          ),
        ],
      ),
    ) ?? false;
  }

  // Verificar permissões necessárias
  static Future<bool> _checkPermissions(BuildContext context) async {
    try {
      // Permissão para instalar APKs (Android 8+)
      final installPermission = await Permission.requestInstallPackages.request();
      
      if (installPermission.isDenied) {
        _showSnackBar(context, 
          '❌ Permissão necessária para instalar apps. Ative nas configurações.', 
          Colors.red);
        return false;
      }

      return true;
    } catch (e) {
      _showSnackBar(context, '❌ Erro ao verificar permissões: $e', Colors.red);
      return false;
    }
  }

  // Download e instalação do APK
  static Future<void> _downloadAndInstallAPK(BuildContext context, String apkUrl) async {
    try {
      _isDownloading = true;
      _downloadProgress = 0.0;

      // Mostrar dialog de progresso
      _showProgressDialog(context);

      // Obter diretório de downloads
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        throw Exception('Não foi possível acessar o armazenamento');
      }

      final fileName = 'seus_lembretes_update.apk';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);

      // Deletar arquivo anterior se existir
      if (await file.exists()) {
        await file.delete();
      }

      // Fazer download com progresso
      final request = http.Request('GET', Uri.parse(apkUrl));
      final response = await request.send();

      if (response.statusCode != 200) {
        throw Exception('Erro no download: ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      int downloadedBytes = 0;
      
      final sink = file.openWrite();
      
      await response.stream.listen((chunk) {
        sink.add(chunk);
        downloadedBytes += chunk.length;
        
        if (contentLength > 0) {
          _downloadProgress = downloadedBytes / contentLength;
        }
      }).asFuture();

      await sink.close();

      // Fechar dialog de progresso
      Navigator.of(context).pop();

      // Instalar APK
      await _installAPK(context, filePath);

    } catch (e) {
      Navigator.of(context).pop(); // Fechar dialog de progresso
      _showSnackBar(context, '❌ Erro no download: $e', Colors.red);
    } finally {
      _isDownloading = false;
    }
  }

  // Mostrar dialog de progresso
  static void _showProgressDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // Atualizar progresso periodicamente
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted(context)) setState(() {});
          });

          return AlertDialog(
            title: const Text('📦 Baixando atualização...'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: _downloadProgress,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                const SizedBox(height: 16),
                Text('${(_downloadProgress * 100).toInt()}%'),
              ],
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          );
        },
      ),
    );
  }

  // Instalar APK
  static Future<void> _installAPK(BuildContext context, String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Arquivo APK não encontrado');
      }

      // Abrir instalador do Android
      final uri = Uri.file(filePath);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        
        _showSnackBar(context, 
          '✅ Instalador aberto! Siga as instruções na tela.', 
          Colors.green);
      } else {
        throw Exception('Não foi possível abrir o instalador');
      }

    } catch (e) {
      _showSnackBar(context, '❌ Erro na instalação: $e', Colors.red);
    }
  }

  // Abrir site para mais detalhes
  static Future<void> openWebsite(BuildContext context) async {
    try {
      const websiteUrl = 'https://seuslembretes.vercel.app';
      final uri = Uri.parse(websiteUrl);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        _showSnackBar(context, '❌ Não foi possível abrir o site', Colors.red);
      }
    } catch (e) {
      _showSnackBar(context, '❌ Erro ao abrir site: $e', Colors.red);
    }
  }

  // Verificar se contexto ainda está montado
  static bool mounted(BuildContext context) {
    try {
      return context.mounted;
    } catch (e) {
      return false;
    }
  }

  // Mostrar SnackBar
  static void _showSnackBar(BuildContext context, String message, Color color) {
    if (mounted(context)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}