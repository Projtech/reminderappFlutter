import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/pin_setup_dialog.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  bool _isSecurityEnabled = false;
  String _authType = 'none';
  bool _isLoading = true;
  int _timeoutMinutes = 5;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    final securityEnabled = await AuthService.isSecurityEnabled();
    final authType = await AuthService.getAuthType();
    final timeoutMinutes = await AuthService.getAuthTimeoutMinutes();

    if (mounted) {
      setState(() {
        _isSecurityEnabled = securityEnabled;
        _authType = authType;
        _timeoutMinutes = timeoutMinutes;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleSecurity(bool enabled) async {
    if (!enabled) {
      // Confirmar desabilitação
      final confirm = await _showConfirmDialog(
        'Desabilitar Segurança?',
        'Isso removerá toda a proteção do app. Tem certeza?',
      );

      if (confirm == true) {
        final success = await AuthService.disableSecurity();
        if (success && mounted) {
          setState(() {
            _isSecurityEnabled = false;
            _authType = 'none';
          });
        }
      }
    } else {
      // Configurar PIN diretamente
      _setupPin();
    }
  }

  Future<bool?> _showConfirmDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Future<void> _setupPin() async {
    final pin = await PinSetupDialog.show(context);
    if (pin != null) {
      final success =
          await AuthService.setupSecurity(authType: 'pin', pin: pin);
      if (success && mounted) {
        setState(() {
          _isSecurityEnabled = true;
          _authType = 'pin';
        });
      }
    }
  }

  Future<void> _updateTimeout(int minutes) async {
    await AuthService.setAuthTimeoutMinutes(minutes);
    setState(() {
      _timeoutMinutes = minutes;
    });
  }

  void _showTimeoutOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Timeout de Autenticação'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Após quanto tempo solicitar autenticação novamente?'),
            const SizedBox(height: 16),
            ...[1, 5, 10, 15, 30, 60].map((minutes) => ListTile(
                  title:
                      Text('$minutes ${minutes == 1 ? 'minuto' : 'minutos'}'),
                  trailing: _timeoutMinutes == minutes
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    _updateTimeout(minutes);
                  },
                )),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }


  String _getAuthTypeDescription() {
    switch (_authType) {
      case 'pin':
        return 'PIN de 4 dígitos';
      default:
        return 'Desabilitada';
    }
  }

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
          'Segurança do App',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Status da Segurança
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isSecurityEnabled ? Icons.lock : Icons.lock_open,
                              color: _isSecurityEnabled
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Status da Segurança',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isSecurityEnabled
                              ? 'Seu app está protegido'
                              : 'Seu app não está protegido',
                          style: TextStyle(
                            color: _isSecurityEnabled
                                ? Colors.green
                                : Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Método: ${_getAuthTypeDescription()}',
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (_isSecurityEnabled) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Timeout: $_timeoutMinutes ${_timeoutMinutes == 1 ? 'minuto' : 'minutos'}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Toggle Principal
                Card(
                  child: SwitchListTile(
                    title: const Text('Habilitar Segurança'),
                    subtitle:
                        const Text('Exigir PIN para abrir o app'),
                    value: _isSecurityEnabled,
                    onChanged: _toggleSecurity,
                    secondary: const Icon(Icons.security),
                  ),
                ),

                if (_isSecurityEnabled) ...[
                  const SizedBox(height: 16),

                  // Alterar PIN
                  Card(
                    child: ListTile(
                      title: const Text('Alterar PIN'),
                      subtitle: const Text('Configurar novo PIN de 4 dígitos'),
                      leading: const Icon(Icons.edit),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: _setupPin,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Configurar Timeout
                  Card(
                    child: ListTile(
                      title: const Text('Timeout de Autenticação'),
                      subtitle: Text(
                          '$_timeoutMinutes ${_timeoutMinutes == 1 ? 'minuto' : 'minutos'}'),
                      leading: const Icon(Icons.schedule),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: _showTimeoutOptions,
                    ),
                  ),

                  const SizedBox(height: 8),

                ],

                const SizedBox(height: 24),

                // Informações
                Card(
                  color: Colors.blue.withValues(alpha: 0.1),
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
                              'Como funciona',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const Text(
                            '• A autenticação é solicitada ao abrir o app'),
                        const Text(
                            '• Após 5 tentativas erradas, o app é temporariamente bloqueado'),
                        const Text(
                            '• Seus dados ficam protegidos apenas no seu dispositivo'),
                        const Text(
                            '• Você pode desabilitar a qualquer momento'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}