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
  bool _biometricAvailable = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    
    final securityEnabled = await AuthService.isSecurityEnabled();
    final authType = await AuthService.getAuthType();
    final biometricAvailable = await AuthService.isBiometricAvailable();
    
    if (mounted) {
      setState(() {
        _isSecurityEnabled = securityEnabled;
        _authType = authType;
        _biometricAvailable = biometricAvailable;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleSecurity(bool enabled) async {
    if (!enabled) {
      // Desabilitar segurança
      final success = await AuthService.disableSecurity();
      if (success && mounted) {
        setState(() {
          _isSecurityEnabled = false;
          _authType = 'none';
        });
        _showMessage('Segurança desabilitada', Colors.orange);
      }
    } else {
      // Mostrar opções para habilitar
      _showSetupOptions();
    }
  }

  void _showSetupOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🔐 Configurar Segurança'),
        content: const Text('Como você deseja proteger seu app?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          if (_biometricAvailable)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _setupBiometric();
              },
              child: const Text('Biometria'),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _setupPin();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('PIN'),
          ),
          if (_biometricAvailable)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _setupBoth();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Ambos'),
            ),
        ],
      ),
    );
  }

  Future<void> _setupBiometric() async {
    final success = await AuthService.setupSecurity(authType: 'biometric');
    if (success && mounted) {
      setState(() {
        _isSecurityEnabled = true;
        _authType = 'biometric';
      });
      _showMessage('Biometria configurada!', Colors.green);
    } else {
      _showMessage('Erro ao configurar biometria', Colors.red);
    }
  }

  Future<void> _setupPin() async {
    final pin = await PinSetupDialog.show(context);
    if (pin != null) {
      final success = await AuthService.setupSecurity(authType: 'pin', pin: pin);
      if (success && mounted) {
        setState(() {
          _isSecurityEnabled = true;
          _authType = 'pin';
        });
        _showMessage('PIN configurado!', Colors.green);
      } else {
        _showMessage('Erro ao configurar PIN', Colors.red);
      }
    }
  }

  Future<void> _setupBoth() async {
    final pin = await PinSetupDialog.show(context);
    if (pin != null) {
      final success = await AuthService.setupSecurity(authType: 'both', pin: pin);
      if (success && mounted) {
        setState(() {
          _isSecurityEnabled = true;
          _authType = 'both';
        });
        _showMessage('Biometria + PIN configurados!', Colors.green);
      } else {
        _showMessage('Erro ao configurar segurança', Colors.red);
      }
    }
  }

  void _showMessage(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _getAuthTypeDescription() {
    switch (_authType) {
      case 'biometric':
        return 'Biometria (Digital/Face)';
      case 'pin':
        return 'PIN de 4 dígitos';
      case 'both':
        return 'Biometria + PIN';
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
                              color: _isSecurityEnabled ? Colors.green : Colors.orange,
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
                            color: _isSecurityEnabled ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Método: ${_getAuthTypeDescription()}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Toggle Principal
                Card(
                  child: SwitchListTile(
                    title: const Text('Habilitar Segurança'),
                    subtitle: const Text('Exigir autenticação para abrir o app'),
                    value: _isSecurityEnabled,
                    onChanged: _toggleSecurity,
                    secondary: const Icon(Icons.security),
                  ),
                ),

                if (_isSecurityEnabled) ...[
                  const SizedBox(height: 16),

                  // Alterar Método
                  Card(
                    child: ListTile(
                      title: const Text('Alterar Método'),
                      subtitle: Text('Atual: ${_getAuthTypeDescription()}'),
                      leading: const Icon(Icons.edit),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: _showSetupOptions,
                    ),
                  ),
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
                        const SizedBox(height: 8),
                        const Text('• A autenticação é solicitada ao abrir o app'),
                        const Text('• Após 3 tentativas erradas, o app é temporariamente bloqueado'),
                        const Text('• Seus dados ficam protegidos apenas no seu dispositivo'),
                        const Text('• Você pode desabilitar a qualquer momento'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}