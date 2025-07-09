import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _pinController = TextEditingController();
  String _authType = 'none';
  bool _isLoading = true;
  bool _isInLockout = false;
  int _lockoutMinutes = 0;
  int _failedAttempts = 0;
  Timer? _lockoutTimer;
  bool _canUsePinFallback = false; // ✅ NOVA VARIÁVEL
  @override
  void initState() {
    super.initState();
    _loadAuthInfo();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAuthInfo() async {
    final authType = await AuthService.getAuthType();
    final isInLockout = await AuthService.isInLockout();
    final lockoutMinutes = await AuthService.getLockoutMinutesRemaining();
    final failedAttempts = await AuthService.getFailedAttempts();
    final hasPinConfigured = await AuthService.hasPinConfigured(); // ✅ NOVO

    if (mounted) {
      setState(() {
        _authType = authType;
        _isInLockout = isInLockout;
        _lockoutMinutes = lockoutMinutes;
        _failedAttempts = failedAttempts;
        _isLoading = false;
        _canUsePinFallback =
            hasPinConfigured && authType == 'biometric'; // ✅ NOVO
      });

      // Se é APENAS biometria, tentar automaticamente
      // Se é 'both', deixar usuário escolher
      if (authType == 'biometric' && !isInLockout) {
        _authenticateWithBiometric();
      }

      _startLockoutTimer();
    }
  }

  void _startLockoutTimer() {
    if (_isInLockout && _lockoutMinutes > 0) {
      _lockoutTimer =
          Timer.periodic(const Duration(seconds: 30), (timer) async {
        final remainingMinutes = await AuthService.getLockoutMinutesRemaining();
        if (mounted) {
          setState(() {
            _lockoutMinutes = remainingMinutes;
          });

          if (remainingMinutes <= 0) {
            setState(() {
              _isInLockout = false;
            });
            timer.cancel();
          }
        } else {
          timer.cancel();
        }
      });
    }
  }

  Future<void> _authenticateWithBiometric() async {
    final success = await AuthService.authenticateWithBiometric();
    if (success && mounted) {
      Navigator.pop(context, true);
    } else if (mounted && _authType == 'biometric') {
      // ✅ NOVO: Perguntar se quer usar PIN
      if (_canUsePinFallback) {
        _showPinFallbackOption();
      } else {
        _showMessage('Falha na autenticação biométrica', Colors.red);
      }
    }
  }

  void _showPinFallbackOption() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Biometria falhou'),
        content: const Text('Deseja usar seu PIN?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _authType = 'pin'; // Temporariamente mudar para PIN
              });
            },
            child: const Text('Usar PIN'),
          ),
        ],
      ),
    );
  }

  Future<void> _authenticateWithPin() async {
    if (_pinController.text.length != 4) return;

    final success = await AuthService.authenticateWithPin(_pinController.text);

    if (success && mounted) {
      Navigator.pop(context, true);
    } else {
      HapticFeedback.heavyImpact();
      _pinController.clear();

      // Recarregar informações para atualizar tentativas e lockout
      await _loadAuthInfo();

      if (_isInLockout) {
        _showMessage(
            'Muitas tentativas! Aguarde $_lockoutMinutes minutos.', Colors.red);
      } else {
        _showMessage(
            'PIN incorreto. Tentativas restantes: ${3 - _failedAttempts}',
            Colors.red);
      }
    }
  }

  void _onNumberPressed(String number) {
    if (_isInLockout) return;

    HapticFeedback.lightImpact();
    if (_pinController.text.length < 4) {
      setState(() {
        _pinController.text += number;
      });

      if (_pinController.text.length == 4) {
        _authenticateWithPin();
      }
    }
  }

  void _onBackspacePressed() {
    if (_isInLockout) return;

    HapticFeedback.lightImpact();
    if (_pinController.text.isNotEmpty) {
      setState(() {
        _pinController.text =
            _pinController.text.substring(0, _pinController.text.length - 1);
      });
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo/Ícone
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.primaryColor,
                      theme.primaryColor.withValues(alpha: 0.7)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(
                  Icons.lock,
                  size: 50,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 30),

              Text(
                'Seus Lembretes',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                _isInLockout
                    ? 'App bloqueado por $_lockoutMinutes minutos'
                    : 'Digite seu PIN para continuar',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: _isInLockout
                      ? Colors.red
                      : theme.textTheme.bodyLarge?.color,
                ),
                textAlign: TextAlign.center,
              ),

              // ✅ NOVO: Mostrar tentativas restantes SEMPRE
              if (!_isInLockout && _failedAttempts > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Tentativas restantes: ${5 - _failedAttempts}',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],

              const SizedBox(height: 40),

              // Indicador de PIN
              if (_authType == 'pin' || _authType == 'both') ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final isFilled = index < _pinController.text.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled
                            ? (_isInLockout ? Colors.red : theme.primaryColor)
                            : Colors.grey[300],
                        border: Border.all(
                          color: isFilled
                              ? (_isInLockout ? Colors.red : theme.primaryColor)
                              : Colors.grey[400]!,
                          width: 2,
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 40),

                // Teclado numérico
                Container(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      if (index == 9) {
                        // Botão biometria (se disponível)
                        if (_authType == 'both' && !_isInLockout) {
                          return _buildBiometricButton(theme);
                        }
                        return const SizedBox();
                      } else if (index == 10) {
                        // Botão 0
                        return _buildNumberButton('0', theme);
                      } else if (index == 11) {
                        // Botão backspace
                        return _buildBackspaceButton(theme);
                      } else {
                        // Botões 1-9
                        return _buildNumberButton(
                            (index + 1).toString(), theme);
                      }
                    },
                  ),
                ),
              ],

// Botão biometria se for só biometria
              if (_authType == 'biometric' && !_isInLockout) ...[
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: _authenticateWithBiometric,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Usar Biometria'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                ),
                // ✅ NOVO: Botão para usar PIN como alternativa
                if (_canUsePinFallback) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _authType = 'pin'; // Mudar temporariamente para PIN
                      });
                    },
                    child: const Text(
                      'Usar PIN',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ],

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberButton(String number, ThemeData theme) {
    return Material(
      elevation: _isInLockout ? 0 : 4,
      borderRadius: BorderRadius.circular(50),
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: _isInLockout ? null : () => _onNumberPressed(number),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isInLockout ? Colors.grey[300] : theme.cardColor,
          ),
          child: Center(
            child: Text(
              number,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: _isInLockout ? Colors.grey : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton(ThemeData theme) {
    return Material(
      elevation: _isInLockout ? 0 : 4,
      borderRadius: BorderRadius.circular(50),
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: _isInLockout ? null : _onBackspacePressed,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isInLockout ? Colors.grey[300] : theme.cardColor,
          ),
          child: Center(
            child: Icon(
              Icons.backspace_outlined,
              size: 24,
              color: _isInLockout ? Colors.grey : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricButton(ThemeData theme) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(50),
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: _authenticateWithBiometric,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.primaryColor.withValues(alpha: 0.1),
          ),
          child: Center(
            child: Icon(
              Icons.fingerprint,
              size: 28,
              color: theme.primaryColor,
            ),
          ),
        ),
      ),
    );
  }
}
