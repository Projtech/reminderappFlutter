import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/reminder.dart';
import '../models/checklist_item.dart';
import '../database/database_helper.dart';

class ChecklistScreen extends StatefulWidget {
  final Reminder reminder;

  const ChecklistScreen({super.key, required this.reminder});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen>
    with TickerProviderStateMixin { // ✅ NOVO: Para as animações
  late List<ChecklistItem> _items;
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final TextEditingController _newItemController = TextEditingController();
  bool _hideCompleted = false;
  bool _isAddingItem = false;
  
  // ✅ Variáveis para o sistema de desfazer
  List<ChecklistItem>? _lastDeletedState;
  ChecklistItem? _lastDeletedItem;
  int? _lastDeletedIndex;

  // ✅ NOVO: Controladores de animação
  late AnimationController _progressAnimationController;
  late Animation<double> _progressAnimation;
  late AnimationController _percentageAnimationController;
  late Animation<double> _percentageAnimation;
  
  double _currentProgress = 0.0;
  int _currentPercentage = 0;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.reminder.checklistItems ?? []);
    
    // ✅ NOVO: Inicializar animações
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _percentageAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: _completionPercentage,
    ).animate(CurvedAnimation(
      parent: _progressAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _percentageAnimation = Tween<double>(
      begin: 0.0,
      end: (_completionPercentage * 100),
    ).animate(CurvedAnimation(
      parent: _percentageAnimationController,
      curve: Curves.easeOutQuart,
    ));

    // ✅ NOVO: Listeners para atualizar o estado
    _progressAnimation.addListener(() {
      setState(() {
        _currentProgress = _progressAnimation.value;
      });
    });

    _percentageAnimation.addListener(() {
      setState(() {
        _currentPercentage = _percentageAnimation.value.round();
      });
    });

    // ✅ NOVO: Iniciar animação
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animateProgress();
    });
  }

  @override
  void dispose() {
    _progressAnimationController.dispose();
    _percentageAnimationController.dispose();
    _newItemController.dispose();
    super.dispose();
  }

  int get _completedCount => _items.where((item) => item.isCompleted).length;
  int get _totalCount => _items.length;
  double get _completionPercentage => _totalCount > 0 ? _completedCount / _totalCount : 0.0;

  List<ChecklistItem> get _filteredItems {
    if (_hideCompleted) {
      return _items.where((item) => !item.isCompleted).toList();
    }
    return _items;
  }

  bool get _canUndo => _lastDeletedState != null && _lastDeletedItem != null && _lastDeletedIndex != null;

  // ✅ NOVO: Função para animar o progresso
  void _animateProgress() {
    final newProgress = _completionPercentage;
    final newPercentage = (newProgress * 100);

    _progressAnimation = Tween<double>(
      begin: _currentProgress,
      end: newProgress,
    ).animate(CurvedAnimation(
      parent: _progressAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _percentageAnimation = Tween<double>(
      begin: _currentPercentage.toDouble(),
      end: newPercentage,
    ).animate(CurvedAnimation(
      parent: _percentageAnimationController,
      curve: Curves.easeOutQuart,
    ));

    _progressAnimationController.reset();
    _percentageAnimationController.reset();
    
    _progressAnimationController.forward();
    _percentageAnimationController.forward();

    // ✅ NOVO: Vibração quando completa 100%
    if (newPercentage == 100.0 && _currentPercentage < 100) {
      Future.delayed(const Duration(milliseconds: 500), () {
        HapticFeedback.mediumImpact();
      });
    }
  }

  Future<void> _saveChanges() async {
    try {
      final updatedReminder = widget.reminder.copyWith(checklistItems: _items);
      await _databaseHelper.updateReminder(updatedReminder);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleItem(int index) {
    final actualIndex = _items.indexOf(_filteredItems[index]);
    setState(() {
      _items[actualIndex] = _items[actualIndex].copyWith(
        isCompleted: !_items[actualIndex].isCompleted,
      );
    });
    _saveChanges();
    HapticFeedback.lightImpact();
    
    // ✅ NOVO: Animar progresso após mudança
    Future.delayed(const Duration(milliseconds: 100), () {
      _animateProgress();
    });
  }

  void _addItem() {
    final text = _newItemController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _items.add(ChecklistItem(
          text: text,
          order: _items.length,
        ));
        _newItemController.clear();
        _isAddingItem = false;
      });
      _saveChanges();
      
      // ✅ NOVO: Animar progresso após adicionar
      Future.delayed(const Duration(milliseconds: 100), () {
        _animateProgress();
      });
    }
  }

  Future<bool> _showDeleteConfirmation(ChecklistItem item) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          title: const Text('Excluir item'),
          content: Text('Deseja excluir "${item.text}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  Future<void> _removeItem(int index) async {
    final actualIndex = _items.indexOf(_filteredItems[index]);
    final itemToDelete = _items[actualIndex];
    
    final shouldDelete = await _showDeleteConfirmation(itemToDelete);
    if (!shouldDelete) return;

    _lastDeletedState = List.from(_items);
    _lastDeletedItem = itemToDelete;
    _lastDeletedIndex = actualIndex;

    setState(() {
      _items.removeAt(actualIndex);
      for (int i = 0; i < _items.length; i++) {
        _items[i] = _items[i].copyWith(order: i);
      }
    });
    
    _saveChanges();

    // ✅ NOVO: Animar progresso após remover
    Future.delayed(const Duration(milliseconds: 100), () {
      _animateProgress();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Item "${itemToDelete.text}" excluído'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _undoDelete() {
    if (_lastDeletedState != null && _lastDeletedItem != null && _lastDeletedIndex != null) {
      setState(() {
        _items = List.from(_lastDeletedState!);
      });
      _saveChanges();
      
      _lastDeletedState = null;
      _lastDeletedItem = null;
      _lastDeletedIndex = null;

      // ✅ NOVO: Animar progresso após desfazer
      Future.delayed(const Duration(milliseconds: 100), () {
        _animateProgress();
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item restaurado com sucesso!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _reorderItems(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _filteredItems.removeAt(oldIndex);
      _filteredItems.insert(newIndex, item);
      
      _items = _filteredItems;
      for (int i = 0; i < _items.length; i++) {
        _items[i] = _items[i].copyWith(order: i);
      }
    });
    _saveChanges();
  }

  void _markAllCompleted() {
    setState(() {
      for (int i = 0; i < _items.length; i++) {
        _items[i] = _items[i].copyWith(isCompleted: true);
      }
    });
    _saveChanges();
    
    // ✅ NOVO: Animar progresso para 100%
    Future.delayed(const Duration(milliseconds: 100), () {
      _animateProgress();
    });
  }

  void _unmarkAll() {
    setState(() {
      for (int i = 0; i < _items.length; i++) {
        _items[i] = _items[i].copyWith(isCompleted: false);
      }
    });
    _saveChanges();
    
    // ✅ NOVO: Animar progresso para 0%
    Future.delayed(const Duration(milliseconds: 100), () {
      _animateProgress();
    });
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
        title: Row(
          children: [
            const Icon(Icons.checklist, color: Colors.blue, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.reminder.title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$_completedCount/$_totalCount',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (_canUndo) ...[
            IconButton(
              onPressed: _undoDelete,
              icon: const Icon(Icons.undo),
              tooltip: 'Desfazer exclusão',
            ),
          ],
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'mark_all':
                  _markAllCompleted();
                  break;
                case 'unmark_all':
                  _unmarkAll();
                  break;
                case 'toggle_completed':
                  setState(() => _hideCompleted = !_hideCompleted);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all',
                child: ListTile(
                  leading: Icon(Icons.done_all),
                  title: Text('Marcar tudo'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'unmark_all',
                child: ListTile(
                  leading: Icon(Icons.clear_all),
                  title: Text('Desmarcar tudo'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'toggle_completed',
                child: ListTile(
                  leading: Icon(_hideCompleted ? Icons.visibility : Icons.visibility_off),
                  title: Text(_hideCompleted ? 'Mostrar concluídos' : 'Ocultar concluídos'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ✅ ATUALIZADO: Header com progresso animado
Container(
 margin: const EdgeInsets.all(16),
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
   color: isDark ? Colors.grey[900] : Colors.white,
   borderRadius: BorderRadius.circular(16),
   boxShadow: [
     BoxShadow(
       color: Colors.black.withValues(alpha: 0.1),
       blurRadius: 8,
       offset: const Offset(0, 2),
     ),
   ],
 ),
 child: Column(
   children: [
     Row(
       mainAxisAlignment: MainAxisAlignment.spaceBetween,
       children: [
         Text(
           'Progresso',
           style: TextStyle(
             fontSize: 16,
             fontWeight: FontWeight.w600,
             color: isDark ? Colors.white : Colors.black,
           ),
         ),
         // ✅ NOVO: Percentual animado com efeito especial quando 100%
         AnimatedBuilder(
           animation: _percentageAnimation,
           builder: (context, child) {
             final isComplete = _currentPercentage >= 100;
             return AnimatedContainer(
               duration: const Duration(milliseconds: 300),
               child: Text(
                 '$_currentPercentage%',
                 style: TextStyle(
                   fontSize: 24,
                   fontWeight: FontWeight.bold,
                   color: isComplete ? Colors.green : Colors.blue,
                 ),
               ),
             );
           },
         ),
       ],
     ),
     const SizedBox(height: 12),
     // ✅ ALTERADO: Barra de progresso da esquerda para direita
     Container(
       height: 8,
       decoration: BoxDecoration(
         borderRadius: BorderRadius.circular(4),
         color: isDark ? Colors.grey[700] : Colors.grey[300],
       ),
       child: AnimatedBuilder(
         animation: _progressAnimation,
         builder: (context, child) {
           final isComplete = _currentProgress >= 1.0;
           return LayoutBuilder(
             builder: (context, constraints) {
               return Stack(
                 children: [
                   // Fundo da barra
                   Container(
                     width: double.infinity,
                     height: 8,
                     decoration: BoxDecoration(
                       borderRadius: BorderRadius.circular(4),
                       color: isDark ? Colors.grey[700] : Colors.grey[300],
                     ),
                   ),
                   // Progresso da esquerda para direita
                   Container(
                     width: constraints.maxWidth * _currentProgress,
                     height: 8,
                     decoration: BoxDecoration(
                       borderRadius: BorderRadius.circular(4),
                       gradient: LinearGradient(
                         colors: isComplete 
                             ? [Colors.green, Colors.lightGreen] // ✅ Verde quando completo
                             : [
                                 const Color(0xFF42A5F5),
                                 const Color(0xFF1E88E5),
                               ],
                       ),
                     ),
                   ),
                 ],
               );
             },
           );
         },
       ),
     ),
     const SizedBox(height: 8),
     Text(
       '$_completedCount de $_totalCount items concluídos',
       style: TextStyle(
         fontSize: 12,
         color: isDark ? Colors.grey[400] : Colors.grey[600],
       ),
     ),
   ],
 ),
),
          
          // Lista de items
          Expanded(
            child: _filteredItems.isEmpty
                ? _buildEmptyState()
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredItems.length,
                    onReorder: _reorderItems,
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      return _buildChecklistItem(item, index);
                    },
                  ),
          ),
          
          // Adicionar item
          if (_isAddingItem) ...[
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newItemController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Digite o novo item...',
                      ),
                      onSubmitted: (_) => _addItem(),
                    ),
                  ),
                  IconButton(
                    onPressed: _addItem,
                    icon: const Icon(Icons.check, color: Colors.green),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isAddingItem = false;
                        _newItemController.clear();
                      });
                    },
                    icon: const Icon(Icons.close, color: Colors.red),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              margin: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _isAddingItem = true);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar Item'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChecklistItem(ChecklistItem item, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      key: ValueKey(item.hashCode),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.isCompleted 
              ? Colors.green.withValues(alpha: 0.3)
              : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
        ),
      ),
      child: ListTile(
        onTap: () => _toggleItem(index),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: item.isCompleted ? Colors.green : Colors.grey,
              width: 2,
            ),
            color: item.isCompleted ? Colors.green : Colors.transparent,
          ),
          child: item.isCompleted
              ? const Icon(Icons.check, color: Colors.white, size: 18)
              : null,
        ),
        title: Text(
          item.text,
          style: TextStyle(
            decoration: item.isCompleted ? TextDecoration.lineThrough : null,
            color: item.isCompleted 
                ? (isDark ? Colors.grey[500] : Colors.grey[600])
                : (isDark ? Colors.white : Colors.black),
            fontSize: 16,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.drag_handle,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            IconButton(
              onPressed: () => _removeItem(index),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              iconSize: 20,
            ),
          ],
        ),
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
            Icons.checklist,
            size: 64,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _hideCompleted ? 'Todos os items foram concluídos!' : 'Nenhum item no checklist',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _hideCompleted ? 'Toque em "Mostrar concluídos" para vê-los' : 'Adicione items para começar',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[500] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}