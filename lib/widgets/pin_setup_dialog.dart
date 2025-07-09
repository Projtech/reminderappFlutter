import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';

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
    
    
    final pinCheck = _checkPinStrength(_enteredPin);
    if (pinCheck['weak'] == 'true') {
      _showWeakPinDialog(pinCheck['reason']!);
      return;
    }
    
    Navigator.pop(context, _enteredPin);
  }

Map<String, String> _checkPinStrength(String pin) {
    // PIN sequencial crescente (1234, 2345, etc)
    final sequences = ['0123', '1234', '2345', '3456', '4567', '5678', '6789'];
    if (sequences.contains(pin)) {
      return {'weak': 'true', 'reason': 'PIN em sequência crescente (ex: 1234)'};
    }
    
    // PIN sequencial decrescente (4321, 9876, etc)
    final reverseSequences = ['3210', '4321', '5432', '6543', '7654', '8765', '9876'];
    if (reverseSequences.contains(pin)) {
      return {'weak': 'true', 'reason': 'PIN em sequência decrescente (ex: 4321)'};
    }
    
    // PIN repetitivo (0000, 1111, etc)
    if (pin[0] == pin[1] && pin[1] == pin[2] && pin[2] == pin[3]) {
      return {'weak': 'true', 'reason': 'PIN com números repetidos (ex: 1111)'};
    }
    
    // PIN alternado simples (1212, 1010, etc)
    if (pin[0] == pin[2] && pin[1] == pin[3] && pin[0] != pin[1]) {
      return {'weak': 'true', 'reason': 'PIN com padrão alternado (ex: 1212)'};
    }
    
    // PINs de datas comuns
    const datePins = [
      '1970', '1980', '1990', '2000', '2010', '2020', '2021', '2022', '2023', '2024', '2025',
      '0101', '0102', '0103', '0104', '0105', '0106', '0107', '0108', '0109', '0110', '0111', '0112',
      '1231', '2512', '0704', '1107', '1509', '1310', '1412', '2502', '3103'
    ];
    if (datePins.contains(pin)) {
      return {'weak': 'true', 'reason': 'PIN é uma data comum'};
    }
    
    // Padrões de teclado
    const keyboardPatterns = [
      '2580', // Coluna central
      '1470', // Coluna esquerda
      '3690', // Coluna direita
      '1590', // Diagonal
      '3570', // Diagonal reversa
      '7410', // Coluna esquerda inversa
      '8520', // Coluna central inversa
      '9630'  // Coluna direita inversa
    ];
    if (keyboardPatterns.contains(pin)) {
      return {'weak': 'true', 'reason': 'PIN segue padrão do teclado numérico'};
    }
    
    // PINs muito comuns
    const commonPins = ['0000', '1234', '1111', '0007', '1004', '2000', '1122', '4545'];
    if (commonPins.contains(pin)) {
      return {'weak': 'true', 'reason': 'PIN está entre os mais usados'};
    }
    
    return {'weak': 'false', 'reason': ''};
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
  }

void _showWeakPinDialog(String reason) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ PIN Fraco'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reason),
            const SizedBox(height: 16),
            const Text(
              'Dicas para um PIN forte:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• Evite sequências (1234, 4321)'),
            const Text('• Não use datas importantes'),
            const Text('• Misture números sem padrão'),
            const Text('• Evite repetições (1111, 1212)'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Exemplo forte: ${_generateStrongPinExample()}',
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isConfirming = false;
                _pinController.clear();
                _confirmController.clear();
                _enteredPin = '';
              });
            },
            child: const Text('Tentar Novamente'),
          ),
        ],
      ),
    );
  }
  
  String _generateStrongPinExample() {
    // Gerar exemplo de PIN forte aleatório
    final random = Random();
    String pin;
    do {
      pin = '';
      for (int i = 0; i < 4; i++) {
        pin += random.nextInt(10).toString();
      }
    } while (_checkPinStrength(pin)['weak'] == 'true');
    return pin;
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

