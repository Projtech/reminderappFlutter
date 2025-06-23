// lib/widgets/whats_new_dialog.dart
import 'package:flutter/material.dart';

class WhatsNewDialog extends StatelessWidget {
  const WhatsNewDialog({super.key});

  static Future<void> show(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => const WhatsNewDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: const Row(
        children: [
          Icon(
            Icons.celebration,
            color: Colors.blue,
            size: 28,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Novidades v1.2.0',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mensagem de boas-vindas
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.new_releases, color: Colors.blue, size: 24),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Confira as melhorias que preparamos para você!',
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

            // Lista de novidades
            _buildFeatureItem(
              icon: Icons.update,
              color: Colors.blue,
              title: 'Verificação Automática',
              description: 'O app agora verifica atualizações automaticamente a cada 12 horas.',
              isDark: isDark,
            ),

            const SizedBox(height: 12),

            _buildFeatureItem(
              icon: Icons.notifications_active,
              color: Colors.orange,
              title: 'Notificações Inteligentes',
              description: 'Alertas discretos quando uma nova versão estiver disponível.',
              isDark: isDark,
            ),

            const SizedBox(height: 12),

            _buildFeatureItem(
              icon: Icons.refresh,
              color: Colors.green,
              title: 'Verificação Manual',
              description: 'Novo botão no menu para verificar quando quiser.',
              isDark: isDark,
            ),

            const SizedBox(height: 12),

            _buildFeatureItem(
              icon: Icons.security,
              color: Colors.purple,
              title: 'Melhorias de Estabilidade',
              description: 'Correções no sistema de notificações e performance.',
              isDark: isDark,
            ),

            const SizedBox(height: 12),

            _buildFeatureItem(
              icon: Icons.lock,
              color: Colors.teal,
              title: 'Privacidade Garantida',
              description: 'Seus dados continuam 100% offline e privados.',
              isDark: isDark,
            ),
          ],
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.check, size: 20),
            label: const Text(
              'Continuar',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
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