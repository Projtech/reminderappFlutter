import 'package:flutter/material.dart';
import '../screens/reminders_list.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    // Obter o tema atual
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      // Usar cor de fundo do tema
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo/Ícone principal
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  // Usar cor primária com opacidade ou cor secundária
                  color: colorScheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(60),
                ),
                child: Icon(
                  Icons.notifications_active,
                  size: 60,
                  // Usar cor sobre a primária ou cor primária
                  color: colorScheme.primary,
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Título
              Text(
                'Lembretes',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  // Usar cor do texto principal do tema
                  color: colorScheme.onBackground,
                ),
              ),
              
              const SizedBox(height: 10),
              
              // Subtítulo
              Text(
                'Nunca mais esqueça seus compromissos importantes',
                style: TextStyle(
                  fontSize: 16,
                  // Usar cor secundária do texto do tema
                  color: colorScheme.onBackground.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 60),
              
              // Botão principal
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RemindersListScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    // Usar cores do tema para ElevatedButton
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  icon: const Icon(Icons.list_alt, size: 24),
                  label: const Text(
                    'Ver Meus Lembretes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Botão secundário (OutlinedButton)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () {
                     Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RemindersListScreen(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    // Usar cores do tema para OutlinedButton
                    foregroundColor: colorScheme.primary, // Cor do texto/ícone
                    side: BorderSide(color: colorScheme.primary, width: 2), // Cor da borda
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 24),
                  label: const Text(
                    'Criar Novo Lembrete',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Informações adicionais
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  // Usar cor de superfície ou primária com opacidade
                  color: colorScheme.surfaceVariant.withOpacity(0.5), 
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.check_circle, 'Notificações personalizadas', colorScheme.onSurfaceVariant),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.repeat, 'Lembretes recorrentes', colorScheme.onSurfaceVariant),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.category, 'Organização por categorias', colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget para as linhas de informação
  Widget _buildInfoRow(IconData icon, String text, Color textColor) {
    return Row(
      children: [
        Icon(icon, color: textColor.withOpacity(0.8), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: textColor, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
