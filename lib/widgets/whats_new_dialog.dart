// lib/widgets/whats_new_dialog.dart
import 'package:flutter/material.dart';
import '../services/app_installer_service.dart';

class WhatsNewDialog extends StatelessWidget {
  final Map<String, dynamic>? updateData;

  const WhatsNewDialog({super.key, this.updateData});

  // Método estático original (mantém compatibilidade)
  static Future<void> show(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => const WhatsNewDialog(),
    );
  }

  // Método para mostrar com dados da API
  static Future<void> showWithData(BuildContext context, Map<String, dynamic> updateData) async {
    return showDialog(
      context: context,
      builder: (context) => WhatsNewDialog(updateData: updateData),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Usar dados da API se disponíveis
    final version = updateData?['version'] ?? '1.3.0';
    final whatsNewData = updateData?['whatsNew'];
    final items = whatsNewData?['items'] as List<dynamic>? ?? [];

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(
            Icons.system_update,
            color: Colors.blue,
            size: 28,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Atualização Disponível v$version', // ✅ MUDADO
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ NOVA mensagem persuasiva
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.star, color: Colors.blue, size: 24),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Uma nova versão está disponível com melhorias importantes!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ✅ Conteúdo persuasivo baseado nos dados da API ou estático
            ...items.isNotEmpty 
                ? _buildPersuasiveFromAPI(items, isDark)
                : _buildPersuasiveStatic(isDark),

            const SizedBox(height: 16),

            // ✅ NOVA seção de benefícios
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.security, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Por que atualizar?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Melhor segurança e estabilidade\n'
                    '• Correções de bugs importantes\n'
                    '• Novos recursos exclusivos\n'
                    '• Performance otimizada',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Botão "Atualizar agora" - mais chamativo
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              AppInstallerService.startUpdate(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.download, size: 20),
            label: const Text(
              'Atualizar agora',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Botão "Ver no site"
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              AppInstallerService.openWebsite(context);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue,
              side: const BorderSide(color: Colors.blue),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.open_in_browser, size: 20),
            label: const Text(
              'Ver detalhes no site',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Botão "Depois"
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text(
              'Depois',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  // ✅ NOVO: Conteúdo persuasivo baseado na API
  List<Widget> _buildPersuasiveFromAPI(List<dynamic> items, bool isDark) {
    final List<Widget> widgets = [];
    
    for (int i = 0; i < items.length; i++) {
      final item = items[i] as Map<String, dynamic>;
      final category = item['category'] as String? ?? 'new';
      final title = item['title'] as String? ?? 'Melhoria importante';
      final description = item['description'] as String? ?? 'Atualização necessária para melhor experiência';
      
      // Tornar descrição mais persuasiva
      final persuasiveDescription = _makeDescriptionPersuasive(description, category);
      
      final iconData = _getIconForCategory(category);
      final color = _getColorForCategory(category);
      
      widgets.add(_buildFeatureItem(
        icon: iconData,
        color: color,
        title: title,
        description: persuasiveDescription,
        isDark: isDark,
      ));
      
      if (i < items.length - 1) {
        widgets.add(const SizedBox(height: 12));
      }
    }
    
    return widgets;
  }

  // ✅ NOVO: Conteúdo persuasivo estático
  List<Widget> _buildPersuasiveStatic(bool isDark) {
    return [
      _buildFeatureItem(
        icon: Icons.security,
        color: Colors.red,
        title: 'Correções de Segurança Críticas',
        description: 'Esta atualização corrige vulnerabilidades importantes. Recomendamos atualizar imediatamente.',
        isDark: isDark,
      ),
      const SizedBox(height: 12),
      _buildFeatureItem(
        icon: Icons.speed,
        color: Colors.blue,
        title: 'Performance Drasticamente Melhorada',
        description: 'Seu app ficará até 50% mais rápido com as otimizações desta versão.',
        isDark: isDark,
      ),
      const SizedBox(height: 12),
      _buildFeatureItem(
        icon: Icons.new_releases,
        color: Colors.green,
        title: 'Recursos Exclusivos',
        description: 'Novos recursos que você não vai querer perder. Disponível apenas na versão mais recente.',
        isDark: isDark,
      ),
      const SizedBox(height: 12),
      _buildFeatureItem(
        icon: Icons.bug_report,
        color: Colors.orange,
        title: 'Bugs Importantes Corrigidos',
        description: 'Resolvemos problemas relatados pelos usuários para uma experiência mais estável.',
        isDark: isDark,
      ),
    ];
  }

  // ✅ NOVO: Tornar descrições mais persuasivas
  String _makeDescriptionPersuasive(String description, String category) {
    switch (category.toLowerCase()) {
      case 'new':
        return 'Novo recurso exclusivo: $description';
      case 'improved':
        return 'Melhoria importante: $description';
      case 'fixed':
        return 'Problema corrigido: $description';
      default:
        return 'Atualização recomendada: $description';
    }
  }

  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'new':
        return Icons.new_releases;
      case 'improved':
        return Icons.upgrade;
      case 'fixed':
        return Icons.bug_report;
      default:
        return Icons.star;
    }
  }

  Color _getColorForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'new':
        return Colors.blue;
      case 'improved':
        return Colors.green;
      case 'fixed':
        return Colors.orange;
      default:
        return Colors.purple;
    }
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}