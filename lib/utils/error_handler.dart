import 'package:flutter/material.dart';
import 'constants.dart'; 

class ErrorHandler {
  static void showError(
    BuildContext context, 
    String message, {
    Duration? duration,
    SnackBarAction? action,
  }) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: AppDimensions.paddingSmall),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: duration ?? AppConstants.snackBarDuration,
        action: action,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        ),
      ),
    );
  }

  static void showSuccess(
    BuildContext context, 
    String message, {
    Duration? duration,
    SnackBarAction? action,
  }) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: AppDimensions.paddingSmall),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: duration ?? AppConstants.snackBarDuration,
        action: action,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        ),
      ),
    );
  }

  static void showWarning(
    BuildContext context, 
    String message, {
    Duration? duration,
    SnackBarAction? action,
  }) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_outlined, color: Colors.white),
            const SizedBox(width: AppDimensions.paddingSmall),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        duration: duration ?? AppConstants.snackBarDuration,
        action: action,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        ),
      ),
    );
  }

  static void showInfo(
    BuildContext context, 
    String message, {
    Duration? duration,
    SnackBarAction? action,
  }) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: AppDimensions.paddingSmall),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        duration: duration ?? AppConstants.snackBarDuration,
        action: action,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        ),
      ),
    );
  }

  // Para logging de erros
  static void logError(String error, [dynamic stackTrace]) {
    debugPrint('🚨 ERROR: $error'); // ✅ CORRIGIDO
    if (stackTrace != null) {
      debugPrint('📍 STACK TRACE: $stackTrace'); // ✅ CORRIGIDO
    }
  }

  // Para casos críticos que quebram o app
  static void handleCriticalError(
    BuildContext context,
    String error, [
    dynamic stackTrace,
  ]) {
    logError(error, stackTrace);
    showError(
      context,
      'Erro crítico: $error\nReinicie o aplicativo.',
      duration: const Duration(seconds: 10),
    );
  }
}

// Exception customizada para o app
class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  AppException(this.message, {this.code, this.originalError});

  @override
  String toString() => 'AppException: $message';
}

// Extensão para validações
extension ValidationExtension on String {
  bool get isValidTitle => trim().isNotEmpty && length <= AppConstants.maxTitleLength;
  bool get isValidDescription => length <= AppConstants.maxDescriptionLength;
  bool get isValidCategoryName => trim().isNotEmpty && length <= AppConstants.maxCategoryNameLength;
  
  String? validateTitle() {
    if (trim().isEmpty) return AppMessages.titleRequired;
    if (length > AppConstants.maxTitleLength) return AppMessages.titleTooLong;
    return null;
  }
  
  String? validateDescription() {
    if (length > AppConstants.maxDescriptionLength) return AppMessages.descriptionTooLong;
    return null;
  }
  
  String? validateCategoryName() {
    if (trim().isEmpty) return 'Nome da categoria é obrigatório';
    if (length > AppConstants.maxCategoryNameLength) return AppMessages.categoryNameTooLong;
    return null;
  }
}