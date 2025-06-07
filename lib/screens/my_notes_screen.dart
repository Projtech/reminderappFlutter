import 'package:flutter/material.dart';
import '../database/note_helper.dart';
import '../models/note.dart';
import 'package:intl/intl.dart';
import 'add_note_screen.dart'; // Importar a tela de adicionar anotação
import '../main.dart'; // Importar o main para acessar a função de troca de tema

class MyNotesScreen extends StatefulWidget {
  const MyNotesScreen({super.key});

  @override
  State<MyNotesScreen> createState() => _MyNotesScreenState();
}

class _MyNotesScreenState extends State<MyNotesScreen> {
  final NoteHelper _noteHelper = NoteHelper();
  final TextEditingController _searchController = TextEditingController();
  List<Note> _notes = [];
  List<Note> _filteredNotes = [];
  bool _isLoading = true;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _filterNotes();
  }

  Future<void> _loadNotes() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final notes = await _noteHelper.getAllNotes();
      if (!mounted) return;
      setState(() {
        _notes = notes;
        _filterNotes();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      // Handle error
    }
  }

  void _filterNotes() {
    setState(() {
      _filteredNotes = _notes.where((note) {
        final matchesSearch = _searchController.text.isEmpty ||
            note.title.toLowerCase().contains(_searchController.text.toLowerCase());
        return matchesSearch;
      }).toList();
    });
  }

  Future<void> _addNote() async {
    // This will be replaced by a proper add note screen later
    final newNote = Note(
      title: 'Nova Anotação ${DateTime.now().second}',
      content: 'Conteúdo da nova anotação.',
      createdAt: DateTime.now(),
    );
    await _noteHelper.insertNote(newNote);
    _loadNotes();
  }

  Future<void> _deleteNote(Note note) async {
    await _noteHelper.deleteNote(note.id!); // Assuming id is not null for existing notes
    _loadNotes();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Anotação \'${note.title}\' excluída.')),
    );
  }

  Future<void> _togglePinNote(Note note) async {
    final updatedNote = note.copyWith(isPinned: !note.isPinned);
    await _noteHelper.updateNote(updatedNote);
    _loadNotes();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Anotação \'${note.title}\' ${updatedNote.isPinned ? 'fixada' : 'desafixada'}.')),
    );
  }

  Future<bool> _showDeleteConfirmation(Note note) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Tem certeza que deseja excluir a anotação \'${note.title}\'?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    ) ?? false;
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
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: 'Pesquisar anotações...', 
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey[600] : Colors.grey[500],
                  ),
                  border: InputBorder.none,
                ),
              )
            : const Text(
                'Minhas Anotações',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                }
              });
            },
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredNotes.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: _filteredNotes.length,
                        itemBuilder: (context, index) {
                          final note = _filteredNotes[index];
                          return _buildNoteItem(note);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddNoteScreen(),
            ),
          );
          if (result == true) {
            _loadNotes();
          }
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_add_outlined,
            size: 80,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 20),
          Text(
            'Nenhuma anotação encontrada.',
            style: theme.textTheme.titleLarge?.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Crie sua primeira anotação para começar!',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.grey[500] : Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoteItem(Note note) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dismissible(
      key: Key(note.id.toString()),
      direction: DismissDirection.endToStart, // Only allow swipe to delete
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) { // Swipe da direita para esquerda (excluir)
          return await _showDeleteConfirmation(note);
        }
        return false;
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          _deleteNote(note);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: note.isPinned
                ? Colors.amber.withOpacity(0.5) // Cor para anotação fixada
                : Colors.transparent,
            width: 1,
          ),
          boxShadow: note.isPinned
              ? [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: ListTile(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddNoteScreen(note: note),
              ),
            );
            if (result == true) {
              _loadNotes();
            }
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Text(
            note.title,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          subtitle: Text(
            'Criado em: ${DateFormat('dd/MM/yyyy HH:mm').format(note.createdAt)}',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          trailing: IconButton(
            icon: Icon(note.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
            color: note.isPinned ? (isDark ? Colors.amber[300] : Colors.amber[700]) : (isDark ? Colors.grey[600] : Colors.grey[400]),
            onPressed: () => _togglePinNote(note),
          ),
        ),
      ),
    );
  }
}




  Widget _buildDrawer() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.blue,
            ),
            child: const Text(
              'Configurações',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          
          ListTile(
            leading: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            title: Text(isDark ? 'Modo Claro' : 'Modo Escuro'),
            trailing: Switch(
              value: isDark,
              onChanged: (value) {
                MyApp.of(context)?.changeTheme(value ? ThemeMode.dark : ThemeMode.light);
              },
            ),
            onTap: () {
              final newMode = isDark ? ThemeMode.light : ThemeMode.dark;
              MyApp.of(context)?.changeTheme(newMode);
            },
          ),
          
          const Divider(),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'SOBRE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Sobre o App'),
            onTap: () {
              Navigator.pop(context);
              showAboutDialog(
                context: context,
                applicationName: 'Minhas Anotações',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2024 ProjTech',
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 15),
                    child: Text(
                      'Este aplicativo permite que você gerencie suas anotações de forma simples e eficiente.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              );
            },
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }


