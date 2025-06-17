import 'package:flutter/material.dart';
import '../services/privacy_settings_service.dart';
import '../widgets/privacy_toggle_card.dart';
import '../widgets/consent_dialog.dart';
import '../utils/app_info.dart';
import '../screens/privacy_screen.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final PrivacySettingsService _privacyService = PrivacySettingsService();
  
  bool _dataCollectionEnabled = false;
  bool _pixSuggestionsEnabled = false;
  int _reportsCount = 0;
  DateTime? _lastDataClear;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    
    final settings = await _privacyService.loadSettings();
    
    setState(() {
      _dataCollectionEnabled = settings['dataCollection'] ?? false;
      _pixSuggestionsEnabled = settings['pixSuggestions'] ?? false;
      _reportsCount = settings['reportsCount'] ?? 0;
      _lastDataClear = settings['lastDataClear'];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[100],
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[100],
        elevation: 0,
        title: const Text(
          'Configurações de Privacidade',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status atual
                _buildStatusCard(context, isDark),
                const SizedBox(height: 16),
                
                // Toggle para coleta de dados
                PrivacyToggleCard(
                  title: 'Coleta de Dados Anônima',
                  subtitle: 'Ajuda a melhorar o app enviando dados de uso anônimos',
                  icon: Icons.analytics_outlined,
                  value: _dataCollectionEnabled,
                  onChanged: _handleDataCollectionToggle,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                
                // Toggle para sugestões PIX
                PrivacyToggleCard(
                  title: 'Sugestões de PIX',
                  subtitle: 'Mostrar sugestões de apoio ao desenvolvedor',
                  icon: Icons.volunteer_activism_outlined,
                  value: _pixSuggestionsEnabled,
                  onChanged: _handlePixSuggestionsToggle,
                  isDark: isDark,
                ),
                const SizedBox(height: 24),
                
                // Dados coletados
                _buildDataInfoCard(context, isDark),
                const SizedBox(height: 16),
                
                // Histórico e ações
                _buildHistoryCard(context, isDark),
                const SizedBox(height: 16),
                
                // Ações de dados
                _buildDataActionsCard(context, isDark),
                const SizedBox(height: 24),
                
                // Link para política completa
                _buildPolicyLinkCard(context, isDark),
              ],
            ),
          ),
    );
  }

  Widget _buildStatusCard(BuildContext context, bool isDark) {
    final statusColor = _dataCollectionEnabled ? Colors.green : Colors.orange;
    final statusText = _dataCollectionEnabled 
        ? '✅ Coleta ativa - Obrigado por ajudar!'
        : '⚠️ Coleta desativada';
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.security, color: statusColor),
                const SizedBox(width: 8),
                Text(
                  'Status Atual',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    _dataCollectionEnabled ? Icons.check_circle : Icons.info,
                    color: statusColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
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

  Widget _buildDataInfoCard(BuildContext context, bool isDark) {
    return Card(
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
                  'Dados Coletados',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _dataCollectionEnabled 
                  ? 'Quando ativo, coletamos apenas:'
                  : 'Nenhum dado está sendo coletado.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
            if (_dataCollectionEnabled) ...[
              const SizedBox(height: 8),
              ...AppInfo.dataCollected.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.circle, size: 6, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 8),
              Text(
                '❌ Nunca coletamos dados pessoais, localização ou conteúdo dos lembretes.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  'Histórico',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildHistoryItem('Reports enviados', _reportsCount.toString()),
            _buildHistoryItem(
              'Última limpeza', 
              _lastDataClear != null 
                  ? '${_lastDataClear!.day}/${_lastDataClear!.month}/${_lastDataClear!.year}'
                  : 'Nunca'
            ),
            _buildHistoryItem(
              'Coleta ativa desde', 
              _dataCollectionEnabled ? 'Hoje' : 'Desativada'
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataActionsCard(BuildContext context, bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.admin_panel_settings, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Controle de Dados',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Botão para limpar dados
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showClearDataDialog,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text(
                  'Limpar Todos os Dados',
                  style: TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // Botão para ver dados
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showDataDetails,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Ver Dados Enviados'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyLinkCard(BuildContext context, bool isDark) {
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PrivacyScreen()),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.article_outlined, color: Colors.blue),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Política de Privacidade Completa',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Ver informações detalhadas sobre privacidade',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  // Handlers dos toggles
  Future<void> _handleDataCollectionToggle(bool value) async {
    if (value && !_dataCollectionEnabled) {
      // Ativar - mostrar dialog de consentimento
      final consent = await _showConsentDialog();
      if (consent == true) {
        await _privacyService.updateDataCollection(true);
        setState(() => _dataCollectionEnabled = true);
        _showSnackBar('✅ Coleta de dados ativada. Obrigado!', Colors.green);
      }
    } else if (!value && _dataCollectionEnabled) {
      // Desativar
      await _privacyService.updateDataCollection(false);
      setState(() => _dataCollectionEnabled = false);
      _showSnackBar('⚠️ Coleta de dados desativada', Colors.orange);
    }
  }

  Future<void> _handlePixSuggestionsToggle(bool value) async {
    await _privacyService.updatePixSuggestions(value);
    setState(() => _pixSuggestionsEnabled = value);
    
    final message = value 
        ? '💝 Sugestões de PIX ativadas'
        : '📵 Sugestões de PIX desativadas';
    _showSnackBar(message, value ? Colors.purple : Colors.grey);
  }

  // Dialogs e ações
Future<bool?> _showConsentDialog() async {
  bool? result;
  
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => ConsentDialog(
      onConsentGiven: (consent) {
        result = consent; // 👈 CAPTURAR O VALOR AQUI
      },
    ),
  );
  
  return result; // 👈 RETORNAR O VALOR
}

  Future<void> _showClearDataDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Limpar Dados'),
        content: const Text(
          'Isso irá apagar permanentemente todos os dados de uso enviados. '
          'Esta ação não pode ser desfeita.\n\n'
          'Deseja continuar?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Limpar Dados'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _privacyService.clearAllData();
      setState(() {
        _reportsCount = 0;
        _lastDataClear = DateTime.now();
      });
      _showSnackBar('🗑️ Todos os dados foram limpos', Colors.red);
    }
  }

  Future<void> _showDataDetails() async {
    final data = await _privacyService.getCollectedDataSummary();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📊 Dados Enviados'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Reports enviados: ${data['reportsCount']}'),
              Text('Primeira coleta: ${data['firstCollection'] ?? 'N/A'}'),
              Text('Última coleta: ${data['lastCollection'] ?? 'N/A'}'),
              const SizedBox(height: 16),
              const Text(
                'Tipos de dados:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...AppInfo.dataCollected.map((item) => Text('• $item')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}