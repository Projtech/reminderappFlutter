import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_info.dart';
import '../widgets/report_bug_dialog.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[100],
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[100],
        elevation: 0,
        title: const Text(
          'Sobre & Apoiar',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Seção Informações
            _buildInfoSection(context, isDark),
            const SizedBox(height: 24),

            // Seção Apoiar
            _buildSupportSection(context, isDark),
            const SizedBox(height: 24),

            // Seção Transparência
            _buildTransparencySection(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context, bool isDark) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Informações',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('App:', AppInfo.appName),
            _buildInfoRow(
                'Versão:', '${AppInfo.version} (${AppInfo.buildNumber})'),
            _buildInfoRow('Atualização:', AppInfo.lastUpdate),
            const SizedBox(height: 10),
            Text(
              AppInfo.createdBy,
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
            Text(
              'Desenvolvido por ${AppInfo.developer}',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportSection(BuildContext context, bool isDark) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.favorite_outline, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Apoiar',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // PIX
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.pix, color: Colors.green, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    AppInfo.pixMessages[0], // Usa a primeira mensagem
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const SelectableText(
                      AppInfo.pixKey,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _copyPixKey(context),
                    icon: const Icon(Icons.copy),
                    label: const Text('Copiar Chave PIX'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Outras formas de apoiar
            ListTile(
              leading: const Icon(Icons.share, color: Colors.blue),
              title: const Text('Compartilhar com amigos'),
              subtitle: const Text('Ajude outras pessoas a conhecer o app'),
              onTap: () => _shareApp(context),
            ),

            ListTile(
              leading: const Icon(Icons.bug_report, color: Colors.orange),
              title: const Text('Reportar bug ou sugestão'),
              subtitle: const Text('Ajude a melhorar o app'),
              onTap: () => _reportBug(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransparencySection(BuildContext context, bool isDark) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.security, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Transparência',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.phone_android, color: Colors.green, size: 32),
                  SizedBox(height: 8),
                  Text(
                    AppInfo.transparencyMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _copyPixKey(BuildContext context) {
    Clipboard.setData(const ClipboardData(text: AppInfo.pixKey));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chave PIX copiada! 😊'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareApp(BuildContext context) {
    // Por enquanto só mostra uma mensagem
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Em breve: Compartilhamento do app'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _reportBug(BuildContext context) {
    ReportBugDialog.show(context);
  }
}
