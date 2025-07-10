// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'dart:async';
import '../database/note_helper.dart';
import '../models/note.dart';

class AddNoteScreen extends StatefulWidget {
  final Note? note;

  const AddNoteScreen({super.key, this.note});

  @override
  State<AddNoteScreen> createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends State<AddNoteScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final NoteHelper _noteHelper = NoteHelper();
  
  bool _isSaving = false;
  bool _hasChanges = false;
  bool _wasSaved = false; // ✅ NOVO: Controla se algo foi salvo
  Note? _currentNote;
  
  // Valores iniciais para comparação
  String _initialTitle = '';
  String _initialContent = '';

  @override
  void initState() {
    super.initState();
    _currentNote = widget.note;
    
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _contentController.text = widget.note!.content;
      _initialTitle = widget.note!.title;
      _initialContent = widget.note!.content;
    }
    
    // Adicionar listeners para auto-save
    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTextChanged);
    _contentController.removeListener(_onTextChanged);
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    // Verifica se houve mudanças reais no conteúdo
    final currentTitle = _titleController.text.trim();
    final currentContent = _contentController.text.trim();
    
    final hasChanges = currentTitle != _initialTitle || currentContent != _initialContent;
    
    if (hasChanges != _hasChanges) {
      setState(() {
        _hasChanges = hasChanges;
      });
    }
    
    // Auto-save imediato se houver mudanças e pelo menos título ou conteúdo não estiver vazio
    if (hasChanges && (currentTitle.isNotEmpty || currentContent.isNotEmpty)) {
      _autoSave();
    }
  }

  Future<bool> _saveOnExit() async {
    final String title = _titleController.text.trim();
    final String content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) return _wasSaved; // ✅ CORRIGIDO: Retorna se algo foi salvo antes
    if (!_hasChanges) return _wasSaved; // ✅ CORRIGIDO: Retorna se algo foi salvo antes

    try {
      if (_currentNote == null) {
        if (title.isNotEmpty) {
          final newNote = Note(
            title: title.isEmpty ? 'Sem título' : title,
            content: content,
            createdAt: DateTime.now(),
          );
          await _noteHelper.insertNote(newNote);
          return true; // ✅ CORRIGIDO: Retorna true quando salva
        }
      } else {
        final updatedNote = _currentNote!.copyWith(
          title: title.isEmpty ? 'Sem título' : title,
          content: content,
        );
        await _noteHelper.updateNote(updatedNote);
        return true; // ✅ CORRIGIDO: Retorna true quando salva
      }
    } catch (e) {
      // Silencioso
    }
    return _wasSaved; // ✅ CORRIGIDO: Retorna se algo foi salvo antes
  }

  Future<void> _autoSave() async {
    final String title = _titleController.text.trim();
    final String content = _contentController.text.trim();

    // Não salva se ambos os campos estão vazios
    if (title.isEmpty && content.isEmpty) {
      return;
    }

    // Não salva se não há mudanças
    if (!_hasChanges) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (_currentNote == null) {
        // Nova anotação - só cria se pelo menos o título não estiver vazio
        if (title.isNotEmpty) {
          final newNote = Note(
            title: title.isEmpty ? 'Sem título' : title,
            content: content,
            createdAt: DateTime.now(),
          );
          
          final insertedId = await _noteHelper.insertNote(newNote);
          _currentNote = newNote.copyWith(id: insertedId);
          
          // Atualiza os valores iniciais
          _initialTitle = title;
          _initialContent = content;
          
          setState(() {
            _hasChanges = false;
            _wasSaved = true; // ✅ NOVO: Marca que algo foi salvo
          });
        }
      } else {
        // Atualizar anotação existente
        final updatedNote = _currentNote!.copyWith(
          title: title.isEmpty ? 'Sem título' : title,
          content: content,
        );
        
        await _noteHelper.updateNote(updatedNote);
        _currentNote = updatedNote;
        
        // Atualiza os valores iniciais
        _initialTitle = title;
        _initialContent = content;
        
        setState(() {
          _hasChanges = false;
          _wasSaved = true; // ✅ NOVO: Marca que algo foi salvo
        });
      }
    } catch (e) {
      // Removido SnackBar conforme solicitado
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _saveNote() async {
    final String title = _titleController.text.trim();
    final String content = _contentController.text.trim();

    if (title.isEmpty) {
      // Removido SnackBar conforme solicitado
      return;
    }

    if (content.isEmpty) {
      // Removido SnackBar conforme solicitado
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (_currentNote == null) {
        // Nova anotação
        final newNote = Note(
          title: title,
          content: content,
          createdAt: DateTime.now(),
        );
        await _noteHelper.insertNote(newNote);
        _wasSaved = true; // ✅ NOVO: Marca que algo foi salvo
        
        // Removido SnackBar conforme solicitado
      } else {
        // Atualizar anotação existente
        final updatedNote = _currentNote!.copyWith(
          title: title,
          content: content,
        );
        await _noteHelper.updateNote(updatedNote);
        _wasSaved = true; // ✅ NOVO: Marca que algo foi salvo
        
        // Removido SnackBar conforme solicitado
      }
      
      if (mounted) {
        Navigator.pop(context, true); // ✅ Sempre retorna true quando salva manualmente
      }
    } catch (e) {
      // Removido SnackBar conforme solicitado
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          final hasChanges = await _saveOnExit();
          if (mounted) {
            Navigator.of(context).pop(hasChanges); // ✅ Agora retorna corretamente se houve mudanças
          }
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[100],
        appBar: AppBar(
          title: Text(widget.note == null ? 'Nova Anotação' : 'Editar Anotação'),
          backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[100],
          elevation: 0,
          actions: [
            // Indicador de mudanças não salvas
            if (_hasChanges && !_isSaving)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Icon(
                  Icons.circle,
                  size: 8,
                  color: Colors.orange,
                ),
              ),
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.check, size: 28),
                onPressed: _saveNote,
                color: Colors.green,
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Campo de título
              TextField(
                controller: _titleController,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Título da anotação',
                  hintStyle: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: null,
              ),
              
              // Linha divisória sutil
              Container(
                height: 1,
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                margin: const EdgeInsets.symmetric(vertical: 16),
              ),
              
              // Campo de conteúdo
              TextField(
                controller: _contentController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Escreva sua anotação aqui...',
                  hintStyle: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                minLines: 20,
              ),
              
              // Espaço extra no final para garantir scroll
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}