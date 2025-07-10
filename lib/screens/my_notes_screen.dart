import 'package:flutter/material.dart';
import '../database/note_helper.dart';
import '../models/note.dart';
import 'package:intl/intl.dart';
import 'add_note_screen.dart';
import 'dart:async';
import 'package:flutter/scheduler.dart';
import '../services/app_state_service.dart';
import '../widgets/unified_drawer.dart';

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
  late StreamSubscription<DataChangeEvent> _dataSubscription;
  late StreamSubscription<LoadingState> _loadingSubscription;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _searchController.addListener(_onSearchChanged);
    _setupDataListener();
    _setupLoadingListener();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dataSubscription.cancel();
    _loadingSubscription.cancel();
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
      // Removido SnackBar conforme solicitado
    }
  }

  void _filterNotes() {
    setState(() {
      _filteredNotes = _notes.where((note) {
        final searchTerm = _searchController.text.toLowerCase();
        return searchTerm.isEmpty ||
            note.title.toLowerCase().contains(searchTerm) ||
            note.content.toLowerCase().contains(searchTerm);
      }).toList();

      // Ordenar: fixadas primeiro, depois por data
      _filteredNotes.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });
    });
  }

  void _setupDataListener() {
    _dataSubscription = AppStateService().dataChanges.listen((event) {
      if (event.type == 'notes' || event.type == 'all') {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _reloadDataSafely();
          }
        });
      }
    });
  }

  void _setupLoadingListener() {
    _loadingSubscription = AppStateService().loadingState.listen((state) {
      if (state.operation == 'backup_import') {
        if (mounted) {
          setState(() {
            _isImporting = state.isLoading;
          });
        }
      }
    });
  }

  Future<void> _reloadDataSafely() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      await _loadNotes();
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
      drawer: const UnifiedDrawer(
        currentScreen: 'notes',
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadNotes,
            child: Column(
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
          ),
          if (_isImporting)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Importando backup...',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Aguarde enquanto restauramos seus dados',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
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
      direction: DismissDirection.endToStart,
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
        if (direction == DismissDirection.endToStart) {
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
                ? Colors.amber.withValues(alpha: 0.5)
                : Colors.transparent,
            width: 1,
          ),
          boxShadow: note.isPinned
              ? [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.2),
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            icon:
                Icon(note.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
            color: note.isPinned
                ? (isDark ? Colors.amber[300] : Colors.amber[700])
                : (isDark ? Colors.grey[600] : Colors.grey[400]),
            onPressed: () => _togglePinNote(note),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteNote(Note note) async {
    try {
      await _noteHelper.deleteNote(note.id!);
      await _loadNotes();

      // Removido SnackBar conforme solicitado
    } catch (e) {
      // Removido SnackBar conforme solicitado
    }
  }

  Future<void> _togglePinNote(Note note) async {
    try {
      final updatedNote = note.copyWith(isPinned: !note.isPinned);
      await _noteHelper.updateNote(updatedNote);
      await _loadNotes();
      // Removido SnackBar conforme solicitado
    } catch (e) {
      // Removido SnackBar conforme solicitado
    }
  }

  Future<bool> _showDeleteConfirmation(Note note) async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Mover para lixeira?'),
            content: Text(
                'A anotação "${note.title}" será movida para a lixeira e poderá ser restaurada posteriormente.'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.orange),
                child: const Text('Mover para Lixeira'),
              ),
            ],
          ),
        ) ??
        false;
  }
}