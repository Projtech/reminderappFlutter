import 'dart:async';
import 'package:flutter/material.dart';


class AppStateService {
  static final _instance = AppStateService._internal();
  factory AppStateService() => _instance;
  AppStateService._internal();

  // Stream para notificar mudanças nos dados
  final _dataChangesController = StreamController<DataChangeEvent>.broadcast();
  Stream<DataChangeEvent> get dataChanges => _dataChangesController.stream;

  // Estado de loading global
  final _loadingController = StreamController<LoadingState>.broadcast();
  Stream<LoadingState> get loadingState => _loadingController.stream;

  // Notificar que dados foram importados
  void notifyDataImported(String type) {
    _dataChangesController.add(DataChangeEvent.imported(type));
  }

// Notificar sucesso com pop-up
// Notificar sucesso SEM pop-up, só com SnackBar
void notifyImportSuccess(BuildContext context, String message) {
  // Notificar que dados foram importados PRIMEIRO
  notifyDataImported('all');
  
  // ✅ SNACKBAR SIMPLES QUE NÃO INTERFERE NA NAVEGAÇÃO
  Future.delayed(const Duration(milliseconds: 300), () {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text(message),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  });
}

  // Controlar estado de loading
  void setLoading(String operation, bool isLoading) {
    _loadingController.add(LoadingState(operation, isLoading));
  }

  void dispose() {
    _dataChangesController.close();
    _loadingController.close();
  }
}

// Modelos para os eventos
class DataChangeEvent {
  final String type; // 'reminders', 'notes', 'all'
  final String action; // 'imported', 'exported', 'deleted'
  
  DataChangeEvent(this.type, this.action);
  DataChangeEvent.imported(this.type) : action = 'imported';
}

class LoadingState {
  final String operation;
  final bool isLoading;
  LoadingState(this.operation, this.isLoading);
}