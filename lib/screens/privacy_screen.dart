// lib/screens/privacy_screen.dart
import 'package:flutter/material.dart';
import '../utils/app_info.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

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
          'Privacidade',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Seção Principal
            _buildMainSection(context, isDark),
            const SizedBox(height: 24),
            
            // O que fazemos
            _buildWhatWeDoSection(context, isDark),
            const SizedBox(height: 24),
            
            // O que coletamos
            _buildDataCollectionSection(context, isDark),
            const SizedBox(height: 24),
            
            // O que NÃO fazemos
            _buildWhatWeDontDoSection(context, isDark),
            const SizedBox(height: 24),
            
            // Seus direitos
            _buildRightsSection(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildMainSection(BuildContext context, bool isDark) {
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
                  'Sua Privacidade',
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
              child: Column(
                children: [
                  const Icon(Icons.phone_android, color: Colors.green, size: 32),
                  const SizedBox(height: 8),
                  const Text(
                    AppInfo.transparencyMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Não vendemos nem compartilhamos seus dados com terceiros.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
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

  Widget _buildWhatWeDoSection(BuildContext context, bool isDark) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'O que fazemos',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildBulletPoint('Seus lembretes ficam armazenados localmente no seu celular', Icons.phone_android),
            _buildBulletPoint('Não exigimos login ou cadastro obrigatório', Icons.no_accounts),
            _buildBulletPoint('Respeitamos todas as leis de proteção de dados (LGPD)', Icons.gavel),
            _buildBulletPoint('Somos transparentes sobre qualquer coleta de dados', Icons.visibility),
          ],
        ),
      ),
    );
  }

Widget _buildDataCollectionSection(BuildContext context, bool isDark) {
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
              Expanded( // ✅ ADICIONADO Expanded aqui
                child: Text(
                  'O que coletamos (apenas se você permitir)',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📱 Dados técnicos para melhorar o app:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...AppInfo.dataCollected.map((item) => _buildBulletPoint(item, Icons.circle, size: 4)),
                const SizedBox(height: 12),
                const Text(
                  '🛠️ Reports de bugs (quando você enviar):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildBulletPoint('Descrição do problema que você escrever', Icons.circle, size: 4),
                _buildBulletPoint('Seu nome/email (apenas se você quiser)', Icons.circle, size: 4),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildWhatWeDontDoSection(BuildContext context, bool isDark) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.block, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'O que NÃO fazemos',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...AppInfo.dataNotCollected.map((item) => _buildBulletPoint(item, Icons.close, color: Colors.red)),
            _buildBulletPoint('Não coletamos dados pessoais sem avisar', Icons.close, color: Colors.red),
            _buildBulletPoint('Não vendemos informações para terceiros', Icons.close, color: Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildRightsSection(BuildContext context, bool isDark) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  'Seus direitos (LGPD)',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildBulletPoint('Desativar coleta de dados a qualquer momento', Icons.toggle_off),
            _buildBulletPoint('Solicitar exclusão dos dados enviados', Icons.delete_outline),
            _buildBulletPoint('Saber exatamente quais dados temos sobre você', Icons.list_alt),
            _buildBulletPoint('Entrar em contato para questões de privacidade', Icons.email),
            
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📧 Contato para questões de privacidade:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const SelectableText(
                    AppInfo.contactEmail,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.purple,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Retenção de dados: ${AppInfo.dataRetentionPeriod}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
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

  Widget _buildBulletPoint(String text, IconData icon, {Color? color, double size = 16}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: size,
            color: color ?? Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}