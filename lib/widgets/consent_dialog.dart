// lib/widgets/consent_dialog.dart
import 'package:flutter/material.dart';
import '../utils/app_info.dart';

class ConsentDialog extends StatelessWidget {
  final Function(bool) onConsentGiven;

  const ConsentDialog({
    super.key,
    required this.onConsentGiven,
  });

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
            Icons.privacy_tip_outlined,
            color: Colors.blue,
            size: 28,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Coleta de Dados',
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
            // Mensagem principal
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.security, color: Colors.green, size: 24),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppInfo.transparencyMessage,
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

            const Text(
              'Para melhorar o app, gostaria de coletar apenas:',
              style: TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 12),

            // Lista do que coleta
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: AppInfo.dataCollected
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.circle,
                                size: 6, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),

            const SizedBox(height: 12),

            Text(
              '❌ Não coletamos dados pessoais, localização ou mensagens.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.red[600],
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              '⚖️ Você pode alterar essa escolha a qualquer momento em "Privacidade".',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _handleChoice(context, false),
          child: Text(
            'Não, obrigado',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => _handleChoice(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Aceitar'),
        ),
      ],
    );
  }

  void _handleChoice(BuildContext context, bool accepted) {
    Navigator.of(context).pop(); // 👈 MUDANÇA AQUI
    onConsentGiven(accepted);
  }
}
