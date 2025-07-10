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
  bool _isLoading = true;
  bool _isInLockout = false;
  int _lockoutMinutes = 0;
  int _failedAttempts = 0;
  Timer? _lockoutTimer;

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
    final isInLockout = await AuthService.isInLockout();
    final lockoutMinutes = await AuthService.getLockoutMinutesRemaining();
    final failedAttempts = await AuthService.getFailedAttempts();

    if (mounted) {
      setState(() {
        _isInLockout = isInLockout;
        _lockoutMinutes = lockoutMinutes;
        _failedAttempts = failedAttempts;
        _isLoading = false;
      });

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

              // Mostrar tentativas restantes
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
}