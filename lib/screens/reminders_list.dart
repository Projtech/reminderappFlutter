import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// import 'package:file_picker/file_picker.dart'; // REMOVIDO - Não usado diretamente aqui
// import 'package:permission_handler/permission_handler.dart'; // REMOVIDO - Não usado diretamente aqui
import '../main.dart'; // Import main.dart para acessar MyApp.of(context)
import '../models/reminder.dart';
import '../database/database_helper.dart';
import '../database/category_helper.dart';
import '../services/notification_service.dart';
import '../services/backup_service.dart'; // ✅ Importar BackupService
import 'add_reminder.dart';
import 'manage_categories_screen.dart';

class RemindersListScreen extends StatefulWidget {
  const RemindersListScreen({super.key});

  @override
  State<RemindersListScreen> createState() => _RemindersListScreenState();
}

class _RemindersListScreenState extends State<RemindersListScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final CategoryHelper _categoryHelper = CategoryHelper();
  final BackupService _backupService = BackupService(); // ✅ Instanciar BackupService
  List<Reminder> _allReminders = []; // Lista original com todos os lembretes
  List<Reminder> _filteredReminders = []; // Lista filtrada para exibição
  Map<String, Color> _categoryColors = {};
  bool _isLoading = true;

  // Filtro por categoria
  String? _selectedFilterCategory = 'Todas'; // Inicia mostrando todas
  List<String> _filterCategories = ['Todas']; // Lista de categorias para o filtro

  // Adicionado para busca
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadData();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // Listener para o campo de busca
  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _filterReminders();
    });
  }

  // Lógica de filtragem combinada (busca e categoria)
  void _filterReminders() {
    List<Reminder> tempReminders = List.from(_allReminders);

    // 1. Filtrar por categoria (se não for "Todas")
    if (_selectedFilterCategory != null && _selectedFilterCategory != "Todas") {
      tempReminders = tempReminders.where((reminder) => reminder.category == _selectedFilterCategory).toList();
    }

    // 2. Filtrar por busca (se houver query)
    if (_searchQuery.isNotEmpty) {
      final queryLower = _searchQuery.toLowerCase();
      tempReminders = tempReminders.where((reminder) {
        final titleLower = reminder.title.toLowerCase();
        final descriptionLower = reminder.description.toLowerCase();
        return titleLower.contains(queryLower) || descriptionLower.contains(queryLower);
      }).toList();
    }

    // Atualiza a lista final filtrada
    setState(() {
      _filteredReminders = tempReminders;
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    await _loadCategories();
    await _loadReminders();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCategories() async {
    try {
      await _categoryHelper.ensureDefaultCategory();
      final categories = await _categoryHelper.getAllCategories();
      final categoryNames = categories.map((c) => c["name"] as String).toList();
      if (mounted) {
        setState(() {
          _categoryColors = {};
          _filterCategories = ["Todas", ...categoryNames]; // Atualiza lista de categorias para filtro
          // Garante que a categoria selecionada ainda exista, senão volta para "Todas"
          if (_selectedFilterCategory != "Todas" && !categoryNames.contains(_selectedFilterCategory)) {
            _selectedFilterCategory = "Todas";
          }
          for (final category in categories) {
            final name = category['name'] as String;
            final colorHex = category['color'] as String;
            try {
              // Adiciona 'FF' para opacidade total ao parsear RRGGBB
              _categoryColors[name] = Color(int.parse('FF$colorHex', radix: 16));
            } catch (e) {
              debugPrint('Erro ao parsear cor $colorHex para categoria $name: $e');
              _categoryColors[name] = Colors.grey;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar categorias: $e');
    }
  }

  Future<void> _loadReminders() async {
    try {
      final reminders = await _databaseHelper.getAllReminders();
      if (mounted) {
        setState(() {
          _allReminders = reminders;
          _allReminders.sort((a, b) => a.dateTime.compareTo(b.dateTime)); // Ordena ao carregar
          _filterReminders(); // Aplica o filtro após carregar
        });
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar lembretes: $e');
    }
  }

  // Função para alternar a visibilidade da barra de busca
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear(); // Limpa a busca ao fechar
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appBarColor = theme.colorScheme.primary;
    final fabColor = theme.colorScheme.secondary;
    final iconColor = theme.colorScheme.onPrimary;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: _buildAppBar(appBarColor, iconColor),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          // Barra de busca (aparece condicionalmente)
          if (_isSearching) _buildSearchBar(),
          // Barra de Filtro de Categoria
          _buildCategoryFilterBar(),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: theme.colorScheme.primary),
                  )
                : _filteredReminders.isEmpty
                    ? _buildEmptyOrNoResultsState()
                    : _buildRemindersList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddEditScreen(),
        backgroundColor: fabColor,
        tooltip: 'Adicionar Lembrete',
        child: Icon(Icons.add, color: theme.colorScheme.onSecondary),
      ),
    );
  }

  // AppBar com lógica de busca e SEM botão de refresh
  AppBar _buildAppBar(Color appBarColor, Color iconColor) {
    return AppBar(
      backgroundColor: appBarColor,
      elevation: 1,
      leading: Builder(
        builder: (context) => IconButton(
          icon: Icon(Icons.menu, color: iconColor),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: Text(
        'Lembretes',
        style: TextStyle(color: iconColor, fontSize: 20, fontWeight: FontWeight.w500),
      ),
      actions: [
        // Ícone de busca
        IconButton(
          icon: Icon(_isSearching ? Icons.close : Icons.search, color: iconColor),
          onPressed: _toggleSearch,
          tooltip: _isSearching ? 'Fechar Busca' : 'Buscar Lembretes',
        ),
      ],
    );
  }

  // Widget da barra de busca
  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: theme.colorScheme.surfaceVariant, // Cor de fundo para destacar
      child: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Buscar por título ou descrição...',
          hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withAlpha((0.7 * 255).round())), // Corrigido de withOpacity
          prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: theme.colorScheme.onSurfaceVariant),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30.0),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
        ),
        style: TextStyle(color: theme.colorScheme.onSurface),
      ),
    );
  }

  // Widget da barra de filtro de categoria
  Widget _buildCategoryFilterBar() {
    final theme = Theme.of(context);
    // Só mostra a barra se houver mais de uma categoria (além de "Todas")
    if (_filterCategories.length <= 2) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: theme.colorScheme.surfaceContainerLowest, // Cor sutil para diferenciar
      child: DropdownButtonFormField<String>(
        value: _selectedFilterCategory,
        items: _filterCategories.map((categoryName) {
          return DropdownMenuItem<String>(
            value: categoryName,
            child: Text(categoryName),
          );
        }).toList(),
        onChanged: (String? newValue) {
          if (newValue != null) {
            setState(() {
              _selectedFilterCategory = newValue;
              _filterReminders(); // Aplica o filtro
            });
          }
        },
        decoration: InputDecoration(
          labelText: 'Filtrar por Categoria',
          labelStyle: TextStyle(color: theme.colorScheme.primary),
          prefixIcon: Icon(Icons.filter_list, color: theme.colorScheme.primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        dropdownColor: theme.colorScheme.surfaceContainerHigh,
        style: TextStyle(color: theme.colorScheme.onSurface),
      ),
    );
  }

  // ✅ Drawer atualizado com opções de Backup
  Widget _buildDrawer() {
    final myAppState = MyApp.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Drawer(
      backgroundColor: colorScheme.surface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
            ),
            child: Text(
              'Configurações',
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontSize: 24,
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.category_outlined, color: colorScheme.onSurfaceVariant),
            title: Text('Gerenciar Categorias', style: TextStyle(color: colorScheme.onSurface)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ManageCategoriesScreen()),
              ).then((_) {
                _loadData(); // Recarrega categorias e lembretes após gerenciar categorias
              });
            },
          ),
          ListTile(
            leading: Icon(Icons.notifications_active_outlined, color: colorScheme.onSurfaceVariant),
            title: Text('Permissões de Notificação', style: TextStyle(color: colorScheme.onSurface)),
            onTap: () async {
              Navigator.pop(context);
              await NotificationService.openNotificationSettingsOrRequest();
              if (mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('Tentando abrir configurações ou solicitar permissão...'), duration: Duration(seconds: 2)),
                 );
              }
            },
          ),
          const Divider(),
          // ✅ Opção Exportar Backup
          ListTile(
            leading: Icon(Icons.upload_file_outlined, color: colorScheme.onSurfaceVariant),
            title: Text('Exportar Backup', style: TextStyle(color: colorScheme.onSurface)),
            onTap: () async {
              Navigator.pop(context); // Fecha o drawer
              await _backupService.exportBackup(context);
            },
          ),
          // ✅ Opção Importar Backup
          ListTile(
            leading: Icon(Icons.file_download_outlined, color: colorScheme.onSurfaceVariant),
            title: Text('Importar Backup', style: TextStyle(color: colorScheme.onSurface)),
            onTap: () async {
              Navigator.pop(context); // Fecha o drawer
              // Confirmação antes de importar (substitui dados atuais)
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Confirmar Importação'),
                  content: const Text('Atenção: Importar um backup substituirá todos os lembretes e categorias atuais (exceto a categoria \'Geral\'). Deseja continuar?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Importar', style: TextStyle(color: Colors.orange)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                final success = await _backupService.importBackup(context);
                if (success && mounted) {
                  // Recarrega os dados na tela após importação bem-sucedida
                  _loadData();
                }
              }
            },
          ),
          const Divider(),
          SwitchListTile(
            title: Text('Modo Escuro', style: TextStyle(color: colorScheme.onSurface)),
            secondary: Icon(
              isDarkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              color: colorScheme.onSurfaceVariant,
            ),
            value: isDarkMode,
            onChanged: (bool value) {
              myAppState?.changeTheme(value ? ThemeMode.dark : ThemeMode.light);
            },
            activeColor: colorScheme.primary,
          ),
        ],
      ),
    );
  }

  // Estado de vazio ou sem resultados de busca
  Widget _buildEmptyOrNoResultsState() {
    final theme = Theme.of(context);
    final bool hasOriginalReminders = _allReminders.isNotEmpty;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasOriginalReminders ? Icons.search_off_outlined : Icons.notifications_none_outlined,
            size: 80,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 20),
          Text(
            hasOriginalReminders ? 'Nenhum resultado encontrado' : 'Nenhum lembrete por aqui',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasOriginalReminders
                ? 'Tente buscar com outros termos.'
                : 'Toque no + para adicionar seu primeiro lembrete.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Lista de lembretes agora usa _filteredReminders
  Widget _buildRemindersList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      itemCount: _filteredReminders.length,
      itemBuilder: (context, index) {
        final reminder = _filteredReminders[index];
        return _buildDismissibleReminderCard(reminder, index);
      },
    );
  }

  Widget _buildDismissibleReminderCard(Reminder reminder, int index) {
    final theme = Theme.of(context);
    return Dismissible(
      key: Key('reminder_${reminder.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: theme.colorScheme.onErrorContainer, size: 32),
            const SizedBox(height: 4),
            Text(
              'Excluir',
              style: TextStyle(
                color: theme.colorScheme.onErrorContainer,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmation(reminder);
      },
      onDismissed: (direction) async {
        await _deleteReminder(reminder, index);
      },
      child: _buildReminderCard(reminder),
    );
  }

  Widget _buildReminderCard(Reminder reminder) {
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    final primaryTextColor = theme.colorScheme.onSurface;
    final secondaryTextColor = theme.colorScheme.onSurfaceVariant;
    final categoryColor = _getCategoryColor(reminder.category);
    final categoryTextColor = categoryColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cardColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showReminderDetailsDialog(reminder),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      reminder.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: categoryColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      reminder.category,
                      style: TextStyle(
                        color: categoryTextColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              if (reminder.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    reminder.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: secondaryTextColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.schedule_outlined, size: 16, color: secondaryTextColor),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(reminder.dateTime),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: secondaryTextColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (reminder.isRecurring) ...[
                    Icon(Icons.repeat_outlined, size: 16, color: theme.colorScheme.secondary),
                    const SizedBox(width: 4),
                    Text(
                      'Mensal', // TODO: Ajustar para mostrar tipo correto de recorrência
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Icon(
                    reminder.notificationsEnabled
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                    size: 18,
                    color: reminder.notificationsEnabled
                        ? theme.colorScheme.primary
                        : secondaryTextColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showReminderDetailsDialog(Reminder reminder) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final categoryColor = _getCategoryColor(reminder.category);
    final categoryTextColor = categoryColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        bool currentNotificationState = reminder.notificationsEnabled;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: colorScheme.surfaceContainerHigh,
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              contentPadding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
              title: Row(
                children: [
                  Icon(Icons.info_outline, color: colorScheme.primary, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Detalhes do Lembrete',
                      style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ListBody(
                  children: <Widget>[
                    const Divider(),
                    _buildDetailRow(Icons.title_outlined, 'Título', reminder.title, colorScheme),
                    if (reminder.description.isNotEmpty)
                      _buildDetailRow(Icons.description_outlined, 'Descrição', reminder.description, colorScheme),
                    _buildDetailRow(
                      Icons.category_outlined,
                      'Categoria',
                      reminder.category,
                      colorScheme,
                      valueWidget: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: categoryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          reminder.category,
                          style: textTheme.bodyMedium?.copyWith(color: categoryTextColor, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                    _buildDetailRow(
                      Icons.calendar_today_outlined,
                      'Data',
                      DateFormat('EEEE, dd MMMM yyyy', 'pt_BR').format(reminder.dateTime),
                      colorScheme,
                    ),
                    _buildDetailRow(
                      Icons.access_time_outlined,
                      'Hora',
                      DateFormat('HH:mm', 'pt_BR').format(reminder.dateTime),
                      colorScheme,
                    ),
                    if (reminder.isRecurring)
                      _buildDetailRow(
                        Icons.repeat_one_outlined,
                        'Recorrência',
                        'Mensal', // TODO: Ajustar tipo
                        colorScheme,
                        valueColor: colorScheme.secondary,
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Icon(Icons.notifications_active_outlined, color: colorScheme.onSurfaceVariant, size: 20),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Notificações',
                              style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
                            ),
                          ),
                          Switch(
                            value: currentNotificationState,
                            onChanged: (bool enabled) async {
                              setDialogState(() {
                                currentNotificationState = enabled;
                              });
                              await _toggleReminderNotification(reminder, enabled);
                            },
                            activeColor: colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('Fechar', style: TextStyle(color: colorScheme.secondary)),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _navigateToAddEditScreen(reminderToEdit: reminder);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, ColorScheme colorScheme, {Color? valueColor, Widget? valueWidget}) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.onSurfaceVariant, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                valueWidget ?? Text(
                  value,
                  style: textTheme.bodyLarge?.copyWith(color: valueColor ?? colorScheme.onSurface),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleReminderNotification(Reminder reminder, bool enabled) async {
    if (reminder.id == null) return;
    try {
      final updatedReminder = reminder.copyWith(notificationsEnabled: enabled);
      await _databaseHelper.updateReminder(updatedReminder);

      if (enabled) {
        await NotificationService.scheduleNotification(
          id: updatedReminder.id!,
          title: updatedReminder.title,
          description: updatedReminder.description,
          scheduledDate: updatedReminder.getNextOccurrence(),
        );
      } else {
        await NotificationService.cancelNotification(reminder.id!);
      }

      if (mounted) {
        setState(() {
          final index = _allReminders.indexWhere((r) => r.id == reminder.id);
          if (index != -1) {
            _allReminders[index] = updatedReminder;
            _filterReminders(); // Re-aplica filtro após alterar notificação
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notificações ${enabled ? "ativadas" : "desativadas"} para "${reminder.title}"'),
            duration: const Duration(seconds: 2),
            backgroundColor: enabled ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erro ao ${enabled ? "ativar" : "desativar"} notificação: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao ${enabled ? "ativar" : "desativar"} notificação.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<bool> _showDeleteConfirmation(Reminder reminder) async {
    final theme = Theme.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: theme.colorScheme.surfaceContainerHigh,
              title: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error, size: 26),
                  const SizedBox(width: 12),
                  Text('Confirmar Exclusão', style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onErrorContainer)),
                ],
              ),
              content: Text('Tem certeza que deseja excluir o lembrete "${reminder.title}"? Esta ação não pode ser desfeita.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              actions: <Widget>[
                TextButton(
                  child: Text('Cancelar', style: TextStyle(color: theme.colorScheme.secondary)),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete_forever_outlined, size: 18),
                  label: const Text('Excluir'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _deleteReminder(Reminder reminder, int indexInFilteredList) async {
    if (reminder.id == null) return;
    try {
      await _databaseHelper.deleteReminder(reminder.id!);
      await NotificationService.cancelNotification(reminder.id!); // Cancela notificação associada
      if (mounted) {
        setState(() {
          // Remove da lista original e da filtrada
          _allReminders.removeWhere((r) => r.id == reminder.id);
          // A linha abaixo estava causando erro se a lista filtrada fosse diferente da original
          // _filteredReminders.removeAt(indexInFilteredList);
          // Em vez disso, apenas refiltramos
          _filterReminders();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lembrete "${reminder.title}" excluído.'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      debugPrint('❌ Erro ao excluir lembrete: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao excluir lembrete.'), backgroundColor: Colors.red),
        );
        _loadReminders(); // Recarrega em caso de erro
      }
    }
  }

  void _navigateToAddEditScreen({Reminder? reminderToEdit}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddReminderScreen(reminderToEdit: reminderToEdit),
      ),
    );

    if (result is Reminder && mounted) {
      setState(() {
        final index = _allReminders.indexWhere((r) => r.id == result.id);
        if (index != -1) {
          // Editando: Atualiza na lista original
          _allReminders[index] = result;
          if (reminderToEdit != null) { // Mostra SnackBar só na edição
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(
                 content: Text('Lembrete "${result.title}" atualizado.'),
                 backgroundColor: Colors.blueAccent,
                 behavior: SnackBarBehavior.floating,
               ),
             );
          }
        } else {
          // Adicionando: Insere na lista original
          _allReminders.insert(0, result);
        }
        // Ordena a lista original e reaplica o filtro
        _allReminders.sort((a, b) => a.dateTime.compareTo(b.dateTime));
        _filterReminders();
      });
    } else if (result == true) {
       _loadReminders(); // Recarrega por segurança se retornar true
    }
  }

  Color _getCategoryColor(String categoryName) {
    return _categoryColors[categoryName] ?? Colors.grey;
  }
}

