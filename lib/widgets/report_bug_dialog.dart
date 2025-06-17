// lib/widgets/report_bug_dialog.dart
import 'package:flutter/material.dart';
import '../services/report_service.dart';
import '../services/profile_service.dart';
import '../services/consent_service.dart';
import '../models/user_profile.dart';

class ReportBugDialog extends StatefulWidget {
  const ReportBugDialog({super.key});

  static Future<void> show(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => const ReportBugDialog(),
    );
  }

  @override
  State<ReportBugDialog> createState() => _ReportBugDialogState();
}

class _ReportBugDialogState extends State<ReportBugDialog> {
  final TextEditingController _messageController = TextEditingController();
  final ProfileService _profileService = ProfileService();
  final ConsentService _consentService = ConsentService();
  
  String _reportType = 'bug';
  bool _includeTechnicalData = false;
  bool _includePersonalInfo = false;
  bool _isLoading = false;
  bool _hasConsent = false;
  bool _hasText = false; // ✅ ADICIONAR esta linha
  UserProfile _userProfile = const UserProfile.empty();
  @override
 void initState() {
  super.initState();
  _loadUserData();
  
  // ✅ ADICIONAR este listener
  _messageController.addListener(() {
    setState(() {
      _hasText = _messageController.text.trim().isNotEmpty;
    });
  });
}
  Future<void> _loadUserData() async {
    final profile = await _profileService.loadProfile();
    final consent = await _consentService.isDataCollectionEnabled();
    
    setState(() {
      _userProfile = profile;
      _hasConsent = consent;
      // ✅ NÃO pré-marcar automaticamente - deixar usuário decidir
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            _reportType == 'bug' ? Icons.bug_report : Icons.lightbulb_outline,
            color: _reportType == 'bug' ? Colors.red : Colors.orange,
            size: 28,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Reportar Bug/Sugestão',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tipo de report
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('🐛 Bug', style: TextStyle(fontSize: 14)),
                    value: 'bug',
                    groupValue: _reportType,
                    onChanged: (value) => setState(() => _reportType = value!),
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('💡 Sugestão', style: TextStyle(fontSize: 14)),
                    value: 'suggestion',
                    groupValue: _reportType,
                    onChanged: (value) => setState(() => _reportType = value!),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Campo de mensagem
            TextField(
              controller: _messageController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: _reportType == 'bug' 
                    ? 'Descreva o problema'
                    : 'Descreva sua sugestão',
                hintText: _reportType == 'bug'
                    ? 'Ex: O app trava quando tento adicionar um lembrete...'
                    : 'Ex: Seria legal ter um modo escuro automático...',
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Checkbox para dados técnicos
            if (_hasConsent) ...[
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Incluir dados técnicos',
                  style: TextStyle(fontSize: 14),
                ),
                subtitle: const Text(
                  'Modelo do celular, versão do Android, versão do app',
                  style: TextStyle(fontSize: 12),
                ),
                value: _includeTechnicalData,
                onChanged: (value) => setState(() => _includeTechnicalData = value!),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  '⚠️ Dados técnicos não serão incluídos (consentimento não dado)',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
            
            const SizedBox(height: 8),
            
            // Checkbox para informações pessoais
            if (_userProfile.hasBasicInfo) ...[
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Incluir meu nome/email',
                  style: TextStyle(fontSize: 14),
                ),
                subtitle: Text(
                  'Nome: ${_userProfile.displayName}${_userProfile.email != null ? '\nEmail: ${_userProfile.email}' : ''}',
                  style: const TextStyle(fontSize: 12),
                ),
                value: _includePersonalInfo,
                onChanged: (value) => setState(() => _includePersonalInfo = value!),
              ),
            ],
            
            const SizedBox(height: 8),
            
            // Aviso sobre envio
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: const Text(
                '📤 Este report será enviado para nos ajudar a melhorar o app.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading || !_hasText
              ? null
              : _sendReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: _reportType == 'bug' ? Colors.red : Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Enviar'),
        ),
      ],
    );
  }

  Future<void> _sendReport() async {
    if (_messageController.text.trim().isEmpty) return;
    
    setState(() => _isLoading = true);
    
    try {
      final success = await ReportService.sendReport(
        message: _messageController.text.trim(),
        type: _reportType,
        userName: _includePersonalInfo ? _userProfile.name : null,
        userEmail: _includePersonalInfo ? _userProfile.email : null,
        includeTechnicalData: _includeTechnicalData,
      );
      
      if (mounted) {
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success 
                  ? '✅ Report enviado! Obrigado por ajudar a melhorar o app.'
                  : '❌ Erro ao enviar report. Tente novamente.',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Erro inesperado ao enviar report.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
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