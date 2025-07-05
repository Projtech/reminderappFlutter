import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PinSetupDialog extends StatefulWidget {
  const PinSetupDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PinSetupDialog(),
    );
  }

  @override
  State<PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<PinSetupDialog> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _isConfirming = false;
  String _enteredPin = '';

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _onNumberPressed(String number) {
    HapticFeedback.lightImpact();
    
    if (!_isConfirming) {
      if (_pinController.text.length < 4) {
        setState(() {
          _pinController.text += number;
        });
        
        if (_pinController.text.length == 4) {
          _enteredPin = _pinController.text;
          setState(() {
            _isConfirming = true;
            _pinController.clear();
          });
        }
      }
    } else {
      if (_confirmController.text.length < 4) {
        setState(() {
          _confirmController.text += number;
        });
        
        if (_confirmController.text.length == 4) {
          _validatePin();
        }
      }
    }
  }

  void _onBackspacePressed() {
    HapticFeedback.lightImpact();
    
    if (!_isConfirming) {
      if (_pinController.text.isNotEmpty) {
        setState(() {
          _pinController.text = _pinController.text.substring(0, _pinController.text.length - 1);
        });
      }
    } else {
      if (_confirmController.text.isNotEmpty) {
        setState(() {
          _confirmController.text = _confirmController.text.substring(0, _confirmController.text.length - 1);
        });
      }
    }
  }

  void _validatePin() {
    if (_enteredPin != _confirmController.text) {
      _showError('PINs não coincidem. Tente novamente.');
      return;
    }
    
    if (_isWeakPin(_enteredPin)) {
      _showError('PIN muito fraco. Evite sequências e repetições.');
      return;
    }
    
    Navigator.pop(context, _enteredPin);
  }

  bool _isWeakPin(String pin) {
    // PIN sequencial (1234, 4321)
    if (pin == '1234' || pin == '4321' || pin == '2345' || pin == '3456' || 
        pin == '5678' || pin == '6789' || pin == '9876' || pin == '8765' ||
        pin == '7654' || pin == '6543' || pin == '5432') {
      return true;
    }
    
    // PIN repetitivo (0000, 1111, etc)
    if (pin[0] == pin[1] && pin[1] == pin[2] && pin[2] == pin[3]) {
      return true;
    }
    
    // PINs muito comuns
    const commonPins = ['0000', '1234', '1111', '2222', '3333', '4444', 
                        '5555', '6666', '7777', '8888', '9999', '1212',
                        '1010', '2020', '1122', '1313', '2323'];
    
    return commonPins.contains(pin);
  }

  void _showError(String message) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
    
    setState(() {
      _isConfirming = false;
      _pinController.clear();
      _confirmController.clear();
      _enteredPin = '';
    });
  }

  void _goBack() {
    if (_isConfirming) {
      setState(() {
        _isConfirming = false;
        _confirmController.clear();
        _pinController.text = _enteredPin;
      });
    } else {
      Navigator.pop(context, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentPin = _isConfirming ? _confirmController.text : _pinController.text;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Título
            Row(
              children: [
                IconButton(
                  onPressed: _goBack,
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Text(
                    _isConfirming ? 'Confirme seu PIN' : 'Crie seu PIN',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 48), // Para balancear o botão de voltar
              ],
            ),

            const SizedBox(height: 20),

            // Indicador de PIN
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isFilled = index < currentPin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled ? theme.primaryColor : Colors.grey[300],
                    border: Border.all(
                      color: isFilled ? theme.primaryColor : Colors.grey[400]!,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 30),

            // Teclado numérico
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.2,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                if (index == 9) {
                  // Botão vazio
                  return const SizedBox();
                } else if (index == 10) {
                  // Botão 0
                  return _buildNumberButton('0');
                } else if (index == 11) {
                  // Botão backspace
                  return _buildBackspaceButton();
                } else {
                  // Botões 1-9
                  return _buildNumberButton((index + 1).toString());
                }
              },
            ),

            const SizedBox(height: 20),

            // Cancelar
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberButton(String number) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(50),
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: () => _onNumberPressed(number),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).cardColor,
          ),
          child: Center(
            child: Text(
              number,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton() {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(50),
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: _onBackspacePressed,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).cardColor,
          ),
          child: const Center(
            child: Icon(Icons.backspace_outlined, size: 24),
          ),
        ),
      ),
    );
  }
}