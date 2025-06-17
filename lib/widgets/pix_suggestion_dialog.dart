// lib/widgets/pix_suggestion_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_info.dart';
import 'dart:math';

class PixSuggestionDialog extends StatelessWidget {
  final VoidCallback? onSupported;
  final VoidCallback? onDeclined;

  const PixSuggestionDialog({
    super.key,
    this.onSupported,
    this.onDeclined,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Escolher uma mensagem aleatória
    final random = Random();
    final randomMessage = AppInfo.pixMessages[random.nextInt(AppInfo.pixMessages.length)];

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              isDark ? const Color(0xFF1A1A1A) : Colors.white,
              isDark ? const Color(0xFF2A2A2A) : Colors.grey[50]!,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 💝 Header com animação
            _buildHeader(isDark),
            
            const SizedBox(height: 20),
            
            // 💬 Mensagem carinhosa
            _buildMessage(randomMessage, isDark),
            
            const SizedBox(height: 24),
            
            // 💳 Seção PIX
            _buildPixSection(context, isDark),
            
            const SizedBox(height: 24),
            
            // 🔘 Botões de ação
            _buildActionButtons(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      children: [
        // Ícone animado
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Colors.pink[300]!, Colors.red[400]!],
            ),
          ),
          child: const Icon(
            Icons.favorite,
            color: Colors.white,
            size: 32,
          ),
        ),
        
        const SizedBox(height: 12),
        
        Text(
          'Apoie o desenvolvimento',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildMessage(String message, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.grey[800],
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            'Seu apoio me motiva a continuar criando!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPixSection(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Logo PIX
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.pix,
                color: Colors.green[600],
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                'PIX',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[600],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Chave PIX
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                const Text(
                  AppInfo.pixKey,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  'Toque para copiar',
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
    );
  }

  Widget _buildActionButtons(BuildContext context, bool isDark) {
    return Row(
      children: [
        // Botão "Talvez depois"
        Expanded(
          child: TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDeclined?.call();
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Talvez depois',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 12),
        
        // Botão "Apoiar agora"
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: () => _copyPixAndClose(context),
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Apoiar agora'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 2,
            ),
          ),
        ),
      ],
    );
  }

  void _copyPixAndClose(BuildContext context) async {
    // Copiar chave PIX
    await Clipboard.setData(const ClipboardData(text: AppInfo.pixKey));
    
    // Fechar modal
    Navigator.pop(context);
    
    // Callback de apoio
    onSupported?.call();
    
    // Mostrar confirmação
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('Chave PIX copiada! Obrigado pelo apoio! 💚'),
              ),
            ],
          ),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}