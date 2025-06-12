import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/note_helper.dart';
import '../models/note.dart';
import 'package:intl/intl.dart';

class NotesTrashScreen extends StatefulWidget {
  const NotesTrashScreen({super.key});

  @override
  State<NotesTrashScreen> createState() => _NotesTrashScreenState();
}

class _NotesTrashScreenState extends State<NotesTrashScreen> {
  final NoteHelper _noteHelper = NoteHelper();
  final TextEditingController _searchController = TextEditingController();
  
  List<Note> _deletedNotes = [];
  List<Note> _filteredNotes = [];
  bool _isLoading = true;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadDeletedNotes();
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

  Future<void> _loadDeletedNotes() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final deletedNotes = await _noteHelper.getDeletedNotes();
      if (mounted) {
        setState(() {
          _deletedNotes = deletedNotes;
          _isLoading = false;
        });
        _filterNotes();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _filterNotes() {
    if (!mounted) return;

    List<Note> filtered = List.from(_deletedNotes);

    // Filtro por pesquisa
    if (_searchController.text.isNotEmpty) {
      final searchTerm = _searchController.text.toLowerCase();
      filtered = filtered
          .where((note) =>
              note.title.toLowerCase().contains(searchTerm) ||
              note.content.toLowerCase().contains(searchTerm))
          .toList();
    }

    setState(() {
      _filteredNotes = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[100],
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Pesquisar na lixeira...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
              )
            : const Text('🗑️ Lixeira de Anotações'),
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[100],
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchController.clear();
                  _filterNotes();
                }
                _isSearching = !_isSearching;
              });
            },
          ),
          if (_deletedNotes.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (value) async {
                switch (value) {
                  case 'empty_trash':
                    await _showEmptyTrashConfirmation();
                    break;
                  case 'clean_old':
                    await _showCleanOldConfirmation();
                    break;
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<String>(
                  value: 'empty_trash',
                  child: ListTile(
                    leading: Icon(Icons.delete_forever, color: Colors.red),
                    title: Text('Esvaziar Lixeira'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'clean_old',
                  child: ListTile(
                    leading: Icon(Icons.auto_delete, color: Colors.orange),
                    title: Text('Limpar Antigos (30+ dias)'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredNotes.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    // Header com informações
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: isDark ? Colors.grey[850] : Colors.grey[100],
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Itens na lixeira: ${_filteredNotes.length}. '
                              'Toque para restaurar ou deslize para excluir permanentemente.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Lista de anotações deletadas
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: _filteredNotes.length,
                        itemBuilder: (context, index) {
                          return _buildDeletedNoteItem(_filteredNotes[index]);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isNotEmpty
                ? 'Nenhuma anotação encontrada na lixeira'
                : 'Lixeira vazia',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchController.text.isNotEmpty
                ? 'Tente pesquisar com outros termos'
                : 'Anotações excluídas aparecerão aqui',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeletedNoteItem(Note note) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Calcular há quanto tempo foi deletado
    final deletedAgo = note.deletedAt != null 
        ? _getTimeAgoText(note.deletedAt!)
        : 'Data desconhecida';

    return Dismissible(
      key: Key('deleted_note_${note.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red[700],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_forever, color: Colors.white, size: 28),
            SizedBox(height: 4),
            Text(
              'Excluir\nPermanentemente',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await _showPermanentDeleteConfirmation(note);
      },
      onDismissed: (direction) {
        _deletePermanently(note);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.orange.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            width: 4,
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  note.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'LIXEIRA',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (note.content.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  note.content,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.delete_outline,
                    size: 14,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Excluída $deletedAgo',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (note.isPinned)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'FIXADA',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.schedule,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Criada em: ${DateFormat('dd/MM/yyyy HH:mm').format(note.createdAt)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(
              Icons.restore,
              color: Colors.blue,
              size: 24,
            ),
            onPressed: () => _restoreNote(note),
            tooltip: 'Restaurar anotação',
          ),
          onTap: () => _showDeletedNoteDetails(note),
        ),
      ),
    );
  }

  String _getTimeAgoText(DateTime deletedAt) {
    final now = DateTime.now();
    final difference = now.difference(deletedAt);

    if (difference.inDays > 0) {
      return 'há ${difference.inDays} dia${difference.inDays == 1 ? '' : 's'}';
    } else if (difference.inHours > 0) {
      return 'há ${difference.inHours} hora${difference.inHours == 1 ? '' : 's'}';
    } else if (difference.inMinutes > 0) {
      return 'há ${difference.inMinutes} minuto${difference.inMinutes == 1 ? '' : 's'}';
    } else {
      return 'há poucos segundos';
    }
  }

  void _showDeletedNoteDetails(Note note) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Badge da lixeira
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                '🗑️ ANOTAÇÃO NA LIXEIRA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Título
            Text(
              note.title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),

            if (note.content.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                note.content,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
            const SizedBox(height: 16),

            _buildDetailRow(
              Icons.delete_outline,
              'Excluída em',
              note.deletedAt != null 
                  ? DateFormat('dd/MM/yyyy HH:mm').format(note.deletedAt!)
                  : 'Data desconhecida',
              color: Colors.orange,
            ),
            const SizedBox(height: 12),

            _buildDetailRow(
              Icons.schedule,
              'Criada em',
              DateFormat('dd/MM/yyyy HH:mm').format(note.createdAt),
              color: Colors.blue,
            ),

            if (note.isPinned) ...[
              const SizedBox(height: 12),
              _buildDetailRow(
                Icons.push_pin,
                'Status',
                'Era uma anotação fixada',
                color: Colors.amber,
              ),
            ],

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _restoreNote(note);
                    },
                    icon: const Icon(Icons.restore),
                    label: const Text('Restaurar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      final confirmed = await _showPermanentDeleteConfirmation(note);
                      if (confirmed) {
                        _deletePermanently(note);
                      }
                    },
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Excluir Permanentemente'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: color ?? (isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color ?? (isDark ? Colors.grey[300] : Colors.grey[700]),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _restoreNote(Note note) async {
    try {
      await _noteHelper.restoreNote(note.id!);
      _loadDeletedNotes();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Anotação "${note.title}" restaurada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao restaurar anotação: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _showPermanentDeleteConfirmation(Note note) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Excluir Permanentemente?'),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 16, color: Colors.black87),
            children: [
              const TextSpan(text: 'A anotação '),
              TextSpan(
                text: '"${note.title}"',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text: ' será excluída permanentemente e ',
              ),
              const TextSpan(
                text: 'NÃO PODERÁ SER RECUPERADA',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const TextSpan(text: '.'),
            ],
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Excluir Permanentemente'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _deletePermanently(Note note) async {
    try {
      await _noteHelper.deleteNotePermanently(note.id!);
      _loadDeletedNotes();

      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Anotação "${note.title}" excluída permanentemente'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir permanentemente: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showEmptyTrashConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🗑️ Esvaziar Lixeira?'),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 16, color: Colors.black87),
            children: [
              TextSpan(
                text: 'TODAS as ${_deletedNotes.length} anotações da lixeira',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' serão '),
              const TextSpan(
                text: 'EXCLUÍDAS PERMANENTEMENTE',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const TextSpan(text: ' e não poderão ser recuperadas.'),
            ],
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Esvaziar Lixeira'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _noteHelper.emptyTrash();
        _loadDeletedNotes();

        if (mounted) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lixeira esvaziada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao esvaziar lixeira: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showCleanOldConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🧹 Limpar Itens Antigos?'),
        content: const Text(
          'Esta ação irá excluir permanentemente todas as anotações que estão na lixeira há mais de 30 dias.\n\n'
          'Esta ação não pode ser desfeita.'
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Limpar Antigos'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final deletedCount = await _noteHelper.cleanOldDeletedNotes(30);
        _loadDeletedNotes();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$deletedCount anotações antigas foram excluídas permanentemente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao limpar itens antigos: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}